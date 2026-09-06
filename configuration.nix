# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, unstablePkgs, ... }:

{
  # ==========================================
  # Core Hardware & Imports
  # ==========================================
  imports = [ 
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # Import Lanzaboote for Secure Boot support(not needed if you have flake lanzaboote)
    #(import (builtins.fetchTarball "https://github.com/nix-community/lanzaboote/archive/master.tar.gz") {}).nixosModules.lanzaboote
  ];

  # Limit build parallelism so heavy compiles (CUDA etc.) don't overheat the CPU
  nix.settings.cores = 2;      # threads per build (was 0 = all 12)
  nix.settings.max-jobs = 1;   # concurrent builds (was auto = 12)

 nix.settings = {
  # Additional binary cache that hosts pre-built CUDA packages.
  # Without this, any package built with cudaSupport = true will be
  # compiled from source locally, which can take a very long time
  # (cache.nixos.org does not build/cache CUDA packages).
  substituters = [
    "https://cache.nixos-cuda.org"
  ];

   # Public key used to verify packages fetched from the cache above.
  # Nix will refuse to use the substituter unless its signature matches this key.
  trusted-public-keys = [
    "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
  ];
};

# Globally enables CUDA support for packages in nixpkgs that support it
# (e.g. blender, ffmpeg, various ML libraries). Combined with the cache
# above, this lets those packages be fetched pre-built instead of compiled.
 nixpkgs.config.cudaSupport = true;




  # ==========================================
  # DNS Configuration — Quad9 with DNS-over-TLS
  # ==========================================
  # Encrypts DNS queries so your ISP/network can't see plaintext
  # DNS lookups. Runs at the OS level via systemd-resolved, so
  # it's transparent to every app (Discord, browsers, games, etc)
  # with zero per-app configuration needed.

  networking.nameservers = [
    "9.9.9.9#dns.quad9.net"        # Quad9 primary, with TLS hostname for DoT verification
    "149.112.112.112#dns.quad9.net" # Quad9 secondary
  ];

  services.resolved = {
    enable = true;
    settings = {
      Resolve = {
        # Encrypts all DNS traffic between your machine and Quad9's servers
        DNSOverTLS = "true";

        # "allow-downgrade" validates DNSSEC when possible but won't
        # hard-fail on networks/domains with broken DNSSEC records.
        # Using "true" instead can cause random unexplained connection
        # failures on some networks — avoid it unless you specifically
        # want strict enforcement.
        DNSSEC = "allow-downgrade";

        # Used only if Quad9 itself is unreachable/down
        FallbackDNS = [ "1.1.1.1" "1.0.0.1" ];
      };
    };
  };

  # Tell NetworkManager to hand DNS duties to systemd-resolved
  # instead of managing it independently — prevents the two from
  # fighting over /etc/resolv.conf
  networking.networkmanager.dns = "systemd-resolved";

  # Prevent NetworkManager from injecting router DHCP DNS servers.
  #
  # The old version of this block used networking.networkmanager.settings
  # with bare "ipv4"/"ipv6" keys — but those sections in NetworkManager.conf
  # only accept [connection] profile keys, so NetworkManager logged
  # "unknown key 'ignore-auto-dns'" warnings and ignored the settings,
  # letting your router's DNS (192.168.1.1) leak in alongside Quad9
  # (verified live on your system via `resolvectl status`).
  #
  # connectionConfig writes to the correct [connection] section, applying
  # to every connection profile (wired + wireless) at once.
  # After rebuild, `resolvectl status` should show ONLY Quad9 on enp5s0.
  networking.networkmanager.connectionConfig = {
    "ipv4.ignore-auto-dns" = true;
    "ipv6.ignore-auto-dns" = true;
  }; 




  # ------------------------------------------
  # Optional Fallback — ASPM Disable
  # ------------------------------------------
  # Only enable this if disabling EEE above does NOT fully fix
  # the disconnects. Some RTL8111 boards also have issues with
  # PCIe Active State Power Management (ASPM) causing similar
  # link renegotiation. This has a minor tradeoff: slightly
  # higher idle power draw. Uncomment only if needed.

  boot.kernelParams = [ "pcie_aspm=off" ];


  # ==========================================
  # Allow Insecure Packages
  # ==========================================
  # Some Electron-based apps depend on Electron 40.10.5, which is
  # EOL and blocked by nixpkgs by default. This explicitly allows
  # it through so the rebuild can proceed.
  #
  # Security note: this keeps a known-outdated/vulnerable
  # component on your system. If you can identify which app pulls
  # in this Electron version, check whether a newer version of
  # that app exists that depends on a supported Electron release —
  # that's the better long-term fix over just allowing this.
  nixpkgs.config.permittedInsecurePackages = [
  "electron-40.10.5"
  "pnpm-10.29.2"
  "electron-39.8.10"
   ];


  # ==========================================
  # NixOS Quality of Life & Optimization
  # ==========================================

  # Thermal safety net for cpu(intel only)
  # services.thermald.enable = true;  

  # Enable modern Nix commands and Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Automated weekly garbage collection to prune system generations older than 7 days
  nix.gc = {
  automatic = true;
  dates = "weekly";
  options = "--delete-older-than 30d";
  };

  # Automatically optimize the Nix store to save disk space
  nix.settings.auto-optimise-store = true;

  # Caps the boot menu to the last 20 generations, regardless of age.
  # Works alongside nix.gc.automatic above — that trims the Nix store
  # by time (30 days), this trims the boot menu by count, so the ESP
  # doesn't slowly fill up with entries even if you rebuild a lot in
  # a short window. Lanzaboote reuses this same option even though
  # systemd-boot.enable is forced off above.
  boot.loader.systemd-boot.configurationLimit = 20;

  # Enable fstrim for SSD health and performance (safely maintains SSD lifespan)
  services.fstrim.enable = true;  # Runs weekly by default

  # Enable nix-ld to run unpatched dynamic binaries (solves non-FHS compliance)
  programs.nix-ld.enable = true;


  # ------------------------------------------
  # nh — NixOS helper CLI
  # ------------------------------------------
  # A friendlier wrapper around nixos-rebuild: `nh os switch` runs the
  # same rebuild as your nix-switch alias but shows a colored diff of what
  # changed, and `nh clean keep 5` browses/prunes old generations in a
  # nice TUI. Pointing it at your flake makes it use /etc/nixos#nixos
  # automatically. Your existing aliases keep working regardless.
  # If enabled: remove `nh` from systemPackages (module installs it).
   programs.nh = {
     enable = true;
     flake = "/etc/nixos";
     clean = {
       enable = true;      # enables the `nh clean` command
       dates = "weekly";   # auto-prune generations weekly (complements nix.gc)
     };
   };



  # ==========================================
  # SSD Longevity & Write Reduction
  # ==========================================

  # ------------------------------------------
  # smartd — automatic disk health monitoring
  # ------------------------------------------
  # You have smartmontools/gsmartcontrol for *manual* checks. smartd
  # watches your disks continuously (near-zero CPU) and raises a warning
  # when a disk starts developing errors — usually weeks before real
  # failure, while you can still act. Check alerts with:
  #     journalctl -t smartd
  # services.smartd.enable = true;

  # Minimizes unnecessary disk writes by keeping ephemeral data
  # in RAM and avoiding metadata churn from access-time updates.

  # ------------------------------------------
  # /tmp in RAM (tmpfs)
  # ------------------------------------------
  # Compiling packages, expanding archives, or running nixos-rebuild generates
  # gigabytes of short-lived temporary files. Keeping /tmp in system memory
  # eliminates millions of write cycles to disk.
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "20%"; # 6.4 GB ceiling on 32GB system

  # ------------------------------------------
  # zRAM Swap & Reduced Swappiness
  # ------------------------------------------
  # Swap writes heavily degrade flash storage over time. Offload swap to
  # compressed RAM and configure the kernel to avoid swapping until
  # absolutely necessary.
  zramSwap.enable = true;
  boot.kernel.sysctl."vm.swappiness" = 10;

  # ------------------------------------------
  # noatime (manual step — see hardware-configuration.nix)
  # ------------------------------------------
  # By default, Linux writes an update to disk every time a file
  # is read, just to record when it was last accessed. Setting
  # noatime disables this, cutting out a large chunk of
  # unnecessary write operations.
  #
  # This can't be set here because fileSystems."/" is already
  # defined in hardware-configuration.nix, and NixOS won't like
  # it being declared twice. Add options = [ "noatime" ]; to the
  # existing fileSystems."/" block there instead.


  # ==========================================
  # Systemd & System Services Configuration
  # ==========================================
  systemd.services = {
    # Disable cgroup-based user session freezing during sleep.
    # This helps prevent Wayland and Plasma crashes after resume.
    "systemd-suspend".environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS =
      "false";

    "systemd-hibernate".environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS =
      "false";

    "systemd-hybrid-sleep".environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS =
      "false";
    



    # ------------------------------------------
    # Realtek Ethernet EEE Disconnect Workaround
    # ------------------------------------------
    # Disables Energy Efficient Ethernet on the Realtek interface.
    #
    # This runs after NetworkManager starts so the interface has
    # time to initialize before ethtool changes its settings.
    "disable-realtek-eee" = {
      description =
        "Disable Energy Efficient Ethernet on the Realtek Ethernet interface";

      wantedBy = [ "multi-user.target" ];
      after = [ "NetworkManager.service" ];
      wants = [ "NetworkManager.service" ];

      serviceConfig = {
        # Run the command once during boot.
        Type = "oneshot";

        # Consider the service complete after it succeeds.
        RemainAfterExit = true;

        # Disable EEE on the enp5s0 Ethernet interface.
        ExecStart =
          "${pkgs.ethtool}/bin/ethtool --set-eee enp5s0 eee off";
      };
    };
  };

  # ------------------------------------------
  # Journald — cap the journal size
  # ------------------------------------------
  # systemd's journal currently consumes 203MB and grows unbounded.
  # This caps it at 200M: systemd keeps the most recent logs within that
  # budget and automatically vacuums older ones. No performance cost —
  # logs are still written exactly the same, old ones are just trimmed.
   services.journald.extraConfig = "SystemMaxUse=200M";





  # ==========================================
  # Bootloader & Kernel Configuration
  # ==========================================
  # Disable default systemd-boot in favor of Lanzaboote (Secure Boot)
  boot.loader.systemd-boot.enable =lib.mkForce false;
  
  # Enable Lanzaboote and define the PKI bundle location
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/etc/secureboot";
  };
  
  # Allow EFI variables to be modified
  boot.loader.efi.canTouchEfiVariables = true;

  # ==========================================
  # AppImage Support
  # ==========================================

  # ------------------------------------------
  # Usage — running, installing, and packaging AppImages
  # ------------------------------------------
  # Three options below, roughly in order of "quick and disposable"
  # to "permanent and proper." Pick whichever matches how much you'll
  # actually use the app.

  # OPTION 1 — RUN (one-off, ad hoc):
  #   With binfmt registered above, just make it executable and run it
  #   directly — no need to invoke appimage-run yourself:
  #     chmod +x ./SomeApp.AppImage
  #     ./SomeApp.AppImage
  #
  #   Without binfmt (or to test on a machine that doesn't have it):
  #     nix-shell -p appimage-run --run "appimage-run ./SomeApp.AppImage"

  # OPTION 2 — "INSTALL" (keep it around, get a menu entry + icon):
  #   NixOS doesn't have a native AppImage installer like some distros
  #   do — there's no apt-style registration step. The normal pattern is:
  #     1. Move the file somewhere permanent, e.g. ~/Applications/
  #     2. Extract its icon/.desktop file so app launchers can see it:
  #          ./SomeApp.AppImage --appimage-extract
  #        This drops a squashfs-root/ folder containing the .desktop
  #        file and icon — copy those into ~/.local/share/applications/
  #        and ~/.local/share/icons/ (edit the Exec= line in the .desktop
  #        file to point at the AppImage's real path).
  #     3. Alternatively, a GUI tool like "gearlever" (available in
  #        nixpkgs) automates steps 1-2 — it manages AppImages, desktop
  #        entries, and updates for you, similar to AppImageLauncher on
  #        other distros. Worth adding to environment.systemPackages if
  #        you plan on collecting more than one or two AppImages.

  # OPTION 3 — PACKAGE PROPERLY (best for an AppImage you use
  # constantly — more upfront work, but it becomes a normal
  # environment.systemPackages entry instead of a loose file you have
  # to remember the path to):
  #
  #   Step 1 — figure out the AppImage type (matters which function
  #   you use below):
  #     file ./SomeApp.AppImage
  #   "ISO 9660" in the output = Type 2 (current standard, most apps).
  #   "ELF" only = Type 1 (older format, rarer now).
  #
  #   Step 2 — write the derivation, e.g. in ~/.config/nixpkgs/someapp.nix
  #   or a local pkgs/someapp/default.nix if you keep one:
  #
  #     { lib, appimageTools, fetchurl }:
  #     let
  #       pname = "someapp";
  #       version = "1.4.0";
  #       src = fetchurl {
  #         url = "https://example.com/releases/SomeApp-${version}.AppImage";
  #         # Leave this blank first, run the build, and Nix will print
  #         # the correct hash to paste in — don't guess it by hand.
  #         hash = "";
  #       };
  #     in
  #     appimageTools.wrapType2 {   # use wrapType1 if step 1 said Type 1
  #       inherit pname version src;
  #
  #       # Fixes the .desktop file's Exec= line so app launchers call
  #       # the wrapped binary instead of the raw, non-executable-as-is AppRun.
  #       extraInstallCommands = ''
  #         substituteInPlace $out/share/applications/${pname}.desktop \
  #           --replace-fail 'Exec=AppRun' 'Exec=${pname}'
  #       '';
  #
  #       meta = {
  #         description = "One-line description of the app";
  #         platforms = [ "x86_64-linux" ];
  #       };
  #     }
  #
  #   Step 3 — wire it into this config:
  #     environment.systemPackages = [
  #       (pkgs.callPackage ./someapp.nix { })
  #       # ... your other packages
  #     ];
  #
  #   Step 4 — build once with an empty hash to get the real one:
  #     sudo nixos-rebuild build --flake /etc/nixos#nixos
  #   Nix will error out with something like:
  #     "hash mismatch ... got: sha256-AbCdEf..."
  #   Paste that value into `hash = "..."` above, then rebuild for real.
  #
  #   From here it behaves like any other Nix package — shows up in
  #   your app launcher with a proper icon, updates when you bump
  #   `version`, and gets cleaned up correctly by garbage collection.
  #-------------------------------------------------------------------------------------------------------
    

  # Registers .AppImage files with binfmt_misc so they can be run
  # directly (e.g. ./someapp.AppImage) without manually invoking
  # appimage-run first. Wraps the same binfmt registration as above,
  # just maintained upstream instead of hand-rolled.
  programs.appimage = {
    enable = true;
    binfmt = true;

    # ------------------------------------------
    # Optional dependency overrides (commented out)
    # ------------------------------------------
    # Nothing is broken yet, so none of this is active. If an AppImage
    # fails to launch, it'll usually print something like:
    #   "error while loading shared libraries: libicuuc.so.XX: cannot
    #    open shared object file"
    # That error tells you exactly which line below to uncomment.
    # Only add what the actual error names — don't uncomment all of
    # these speculatively, since some (torch especially) are multi-GB.
    #
    # package = pkgs.appimage-run.override {
    #   extraPkgs = pkgs: [
    #     pkgs.icu                    # Fixes "libicuuc.so" / "libicui18n.so" errors — common in Electron/Qt AppImages
    #     pkgs.libxcrypt-legacy       # Fixes "libcrypt.so.1" errors — older AppImages built against legacy glibc/crypt
    #     pkgs.python312              # Only if the AppImage bundles/calls a system Python 3.12 interpreter
    #     pkgs.python312Packages.torch # Only for ML/AI AppImages that expect PyTorch on the host (heavy, GBs in size)
    #   ];
    # };

  };

  # Use the latest Linux kernel(_latest) or LTS
  boot.kernelPackages = pkgs.linuxPackages;

  # ==========================================
  # Networking & Localization
  # ==========================================
  # Define your system hostname
  networking.hostName = "nixos"; 

  # Enable NetworkManager for wired and wireless connections
  networking.networkmanager.enable = true;

  # Set your primary time zone
  time.timeZone = "America/Toronto";

  # Select internationalisation/locale properties
  i18n.defaultLocale = "en_CA.UTF-8";


  # ==========================================
  # Hardware & Drivers (NVIDIA & Bluetooth)
  # ==========================================

  # Allow installation of proprietary software (Required for NVIDIA)
  nixpkgs.config.allowUnfree = true;

  # Load the proprietary NVIDIA driver for both X11 and Wayland
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Saves VRAM video memory content to disk before sleep and
    # restores it on wake. Prevents KWin and Plasma from losing
    # display buffers and crashing upon resume.
    powerManagement.enable = true;

    # Enables Kernel Mode Setting (KMS), which is required for
    # proper display mode restoration on wake and mandatory for
    # Wayland compositors.
    modesetting.enable = true;
    open = false; # Use proprietary drivers (best for TU116 cards)
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  environment.sessionVariables = {
    # Direct GLX apps to NVIDIA driver
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    # Hardware acceleration support
    # LIBVA_DRIVER_NAME = "nvidia"; (keep disabled for now to fix vesktop)

    # Forces Electron / Chromium apps to run natively in Wayland (NixOS specific)
    # (upscayl wont work with this workaround here)
    # env -u NIXOS_OZONE_WL upscayl --ozone-platform=x11 %U
    # NIXOS_OZONE_WL = "1";
  };

  # Enable OpenGL/Graphics support (including 32-bit for gaming)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Enables the BlueZ Bluetooth service system-wide
  hardware.bluetooth = {
    enable = true;

    # Ensures Bluetooth is automatically turned on when the computer boots up
    powerOnBoot = true;

    # Advanced features configuration
    settings = {
      General = {
        # Enables experimental features (like reading battery levels)
        Experimental = true;
      };
    };
  };

  services.pipewire.wireplumber.extraConfig."bluetooth-config" = {
    # Configure Bluetooth audio devices handled by the BlueZ monitor.
    "monitor.bluez.properties" = {
      # Enable SBC-XQ, a higher-quality variant of the standard SBC codec.
      # This may improve Bluetooth audio quality when the headset supports it.
      "bluez5.enable-sbc-xq" = true;

      # Enable mSBC, the wideband speech codec used for higher-quality
      # Bluetooth microphone audio during headset/profile conversations.
      "bluez5.enable-msbc" = true;

      # Let the Bluetooth device control its own hardware volume.
      # This can provide smoother volume behavior, but may cause volume-sync
      # issues with some headphones.
      # "bluez5.enable-hw-volume" = true;
    };
  };
 
  # ==========================================
  # Display Manager & Desktop Environment
  # ==========================================
  # Enable the X11 windowing system (can be disabled if strictly using Wayland)
  services.xserver.enable = true;

  # Configure X11 keyboard layout
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # ==========================================
  # KDE Desktop Environment + SDDM
  # ==========================================

  # Enable the SDDM Display Manager and KDE Plasma 6 Desktop Environment
  services.displayManager.sddm.enable = true;

  # Qylock's SDDM themes are Qt6/Wayland based — run the greeter itself
  # under Wayland so they render correctly.
  services.displayManager.sddm.wayland.enable = true;

  services.desktopManager.plasma6.enable = true;



  # Enable KDE’s balanced power profile
  services.power-profiles-daemon.enable = true;  

  # Enable XWayland support for legacy apps running under Wayland
  programs.xwayland.enable = true;


  # ==========================================
  # XFCE Desktop Environment (Chicago95)
  # ==========================================
  # Registers "Xfce Session" in SDDM next to Plasma — both stay available,
  # you pick per-login. XFCE 4.20 is a classic X11 session: the most
  # trouble-free pairing with your NVIDIA driver (no Wayland quirks) and
  # your existing X11-fix wrappers (vesktop/sioyek/upscayl run natively,
  # no env hacks needed). The module auto-enables polkit-gnome agent,
  # NM tray applet, pulseaudio plugin + pavucontrol, screensaver + PAM,
  # udisks2/gvfs/tumbler, gtk+xapp portals.
  services.xserver.desktopManager.xfce.enable = true;

  # Allow bitmap fonts (cronyx-cyrillic "Helvetica"). This is the NixOS
  # equivalent of the upstream doc's "mv /etc/fonts/conf.d/70-no-bitmaps.conf"
  # step — done declaratively instead of hacking /etc.
  fonts.fontconfig.allowBitmaps = true;

    

  # ==========================================
  # Qylock (SDDM themes / Quickshell lockscreen)
  # ==========================================
  # Provided by the qylock flake input + qylock.nixosModules.default
  # in flake.nix.
  programs.qylock = {
    enable = true;

    # Pick any directory name under qylock's `themes/` folder, e.g.
    # "nier-automata", "terraria", "clockwork", "pixel-coffee", etc.
    # Check https://github.com/Darkkal44/qylock#-gallery for the full list.
    theme = "nier-automata";

    # Installs the theme into share/sddm/themes and sets it as the
    # active SDDM theme (default: true).
    # sddm.enable = true;

    # Adds the `qylock-lock` binary to PATH so a WM keybind can call
    # it to lock the screen via Quickshell.
    #
    # NOTE: the Quickshell lockscreen requires compositor support for
    # the ext-session-lock-v1 protocol. KWin (KDE Plasma, which you're
    # using here) does NOT support this yet, so qylock-lock will not
    # actually lock the screen under Plasma — only the SDDM login-screen
    # theme above will work for you right now. This only becomes useful
    # if you switch to a wlroots-based compositor like Hyprland (see the
    # commented-out programs.hyprland block further down).
    # quickshell.enable = false;

    # Optional per-theme tweaks (skips qylock's interactive prompts).
    # Uncomment/adjust if your chosen theme supports these:
    # themeOptions = {
    #   terraria.backgroundMode = "time";   # time | random | static
    #   Genshin.backgroundMode = "time";
    #   clockwork.orbital = { themeMode = "dark"; enableWindup = true; };
    #   osu.gameMode = "menu";              # menu | game
    # };
  };  





  # ------------------------------------------
  # XDG Desktop Portals Configuration
  # ------------------------------------------
  # KDE Plasma and Hyprland have their own preferred portals.
  # GTK remains the general fallback.
  #
  # The wlroots portal is installed for possible future MangoWC
  # use, but it is not selected as the default for any session yet.
  xdg.portal = {
    enable = true;
    extraPortals = [
      # General GTK dialogs, file pickers, and fallback support.
      pkgs.xdg-desktop-portal-gtk
      # Hyprland screen sharing and Wayland integration.
      pkgs.xdg-desktop-portal-hyprland
      # Generic wlroots portal.
      # Kept installed for possible future MangoWC use.
      pkgs.xdg-desktop-portal-wlr
      # KDE Plasma screen sharing and desktop integration.
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
    config = {
      # Hyprland uses its native portal first,
      # with GTK available as a fallback.
      hyprland.default = [
        "hyprland"
        "gtk"
      ];
      # KDE Plasma uses its native portal first,
      # with GTK available as a fallback.
      kde.default = [
        "kde"
        "gtk"
      ];

      # XFCE uses its native xapp portal first, GTK as fallback.
      xfce.default = [
        "xapp"
        "gtk"
      ];

      # GTK is the general fallback for applications that
      # do not clearly identify their desktop environment.
      common.default = [
        "gtk"
      ];
    };
  };

  ##################################################
  # MangoWC Portal Configuration (unused)
  ##################################################
  # Uncomment this section if you start using MangoWC
  # and it identifies the session as "mango".
  #
  # xdg.portal.config.mango.default = [
  #   "wlr"
  #   "gtk"
  # ];
  # xdg.portal.config.wlroots.default = [
  #   "wlr"
  #   "gtk"
  # ];


  # ==========================================
  # Audio & Printing Services
  # ==========================================
  # Enable CUPS to print documents
  services.printing.enable = true;

  # Disable legacy PulseAudio in favor of Pipewire
  services.pulseaudio.enable = false;
  
  # Realtime Kit scheduling for optimal audio performance
  security.rtkit.enable = true;
  
  # Enable and configure Pipewire for modern audio routing
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true; # Uncommented to support JACK applications
    wireplumber.enable= true;
  };

  # ==========================================
  # Virtualization
  # ==========================================
  # Enable libvirtd and configure optimal KVM/QEMU settings for VM performance
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      };
    };

  # Enable Virt-Manager GUI
  programs.virt-manager.enable = true;
  
  # Enable Spice redirection for USB passthrough
  virtualisation.spiceUSBRedirection.enable = true;

  # ------------------------------------------
  # Podman — daemonless container backend
  # ------------------------------------------
  # Replaces the old Docker setup. Docker's daemon runs nonstop in the
  # background; Podman is "daemonless": nothing runs until you actually
  # start a container, then the process spins up on demand. Zero idle
  # CPU, zero idle memory — exactly "docker when I need it, not running
  # all the time".
  #
  #   dockerCompat    → installs a `docker` CLI shim pointing at podman,
  #                     so `docker ps`, `docker run`, etc. all work.
  #   dockerSocket    → activates the docker-compatible API socket
  #                     (socket-activated, starts on demand), so tools
  #                     that talk to the Docker API — including winboat
  #                     — work without a permanent daemon.
  #
  # If you ever want the REAL Docker daemon instead, delete this block
  # and enable virtualisation.docker.enable = true; instead.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;        # `docker` command → podman
    dockerSocket.enable = true; # docker-API tools (winboat) work, on demand
  };

  # ==========================================
  # Users & Shell Configuration
  # ==========================================
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."fury" = {
    isNormalUser = true;
    description = "Fury";
    extraGroups = [
      "networkmanager"  # manage network connections without a password prompt
      "wheel"           # sudo access
      "libvirtd"        # access your VMs in virt-manager without "access denied"
      # "wireshark"    # packet capture without sudo — uncomment IF you enable
      #                # programs.wireshark in the optional section below
    ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };
  
  # ------------------------------------------
  # Trusted user — passwordless nix commands
  # ------------------------------------------
  # Adds you to nix's trusted-users list. Effect: commands like
  # `nix profile install`, `nh os switch`, and later Home Manager can
  # rebuild/install without typing your sudo password every time.
  # On a single-user desktop where you already have wheel/sudo, this is a
  # convenience, not a security boundary change.
   nix.settings.trusted-users = [ "root" "fury" ];


  # ==========================================
  # Cursor Configuration
  # ==========================================

  # Set global fallback cursor environment variables for GTK, X11, and Wayland
  # Note: Ensure 'google-cursor' is added to environment.systemPackages above
  environment.variables = {
    # make sure to add in Nixpkgs
    # Choose variant: GoogleDot-Blue, GoogleDot-Black, GoogleDot-White, or GoogleDot-Red
    # other themes : phinger-cursors(Most over-engineered cursor theme),  Borealis-cursors , 
    # MAC OS LIKE cursors: apple-cursor(Free & Open source macOS Cursors), afterglow-cursors-recolored
    # Windows like cursors: openzone-cursors
    # Best cursors: bibata-cursors-translucent, bibata-cursors, 

    XCURSOR_THEME = "GoogleDot-Black";

    # Standard cursor sizes: 22 ,24, 32, 48, 64
    XCURSOR_SIZE = "22";
  };

  
  # ==========================================
  # Zsh Configuration & Aliases
  # ==========================================
  programs.zsh = {
    enable = true;

    # Keep true: this links /share/zsh (all package completions) into fpath
    # and installs nix-zsh-completions. Setting it false breaks completions.
    enableCompletion = true;

    # NEW (replaces "enableCompletion = false"): removes ONLY the duplicate
    # compinit call from /etc/zshrc. Oh My Zsh runs its own compinit anyway.
    enableGlobalCompInit = false;

    # Flat option (NOT history = { ... }) — sets both HISTSIZE and SAVEHIST.
    # histFile already defaults to ~/.zsh_history, no need to set it.
    histSize = 10000;

    autosuggestions.enable = true; # gray suggestions from history as you type
    syntaxHighlighting.enable = true; # red invalid commands, green valid ones

    # ---------- Oh My Zsh ----------
    #
    # Gives you a prompt theme plus curated plugins.
    ohMyZsh = {
      enable = true;

      # Set a bundled theme name here (e.g. "agnoster", "robbyrussell", "af-magic").
      # Leave this line as-is if using a custom (non-bundled) theme below instead.
      theme = "af-magic";
      plugins = [
        # "git"     # git aliases (gst, gco, gcmsg, gp, etc.)
        "sudo"
        # "docker"  # tab-completion for docker commands
      ];

    };

    # ---------- Custom (non-bundled) theme setup ----------
    #
    # Only needed if you want a theme NOT shipped with Oh My Zsh,
    # e.g. powerlevel10k or spaceship. If you use this, comment out
    # the `theme = "agnoster";` line above so they don't conflict.
    #
    # ohMyZsh.plugins = [
    #   {
    #     name = "powerlevel10k";
    #     src = pkgs.zsh-powerlevel10k;
    #     file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    #   }
    # ];

  shellAliases = {
    # ---------- Everyday commands ----------
    #
    # Use these for common navigation, listings,
    # file viewing, and terminal tasks.

    # Modern replacement for ls with icons.
    ls = "eza --icons";

    # Detailed listing with hidden files and readable sizes.
    ll = "eza -lah --icons";

    # List directories only.
    lsd = "eza -l --icons --only-dirs";

    # Modern cat replacement with syntax highlighting.
    cat = "bat";

    # Move up one directory.
    ".." = "cd ..";

    # Show the size of every item in the current directory.
    duh = "du -sh ./*";

    # Clear the terminal screen.
    c = "clear";

    # Replace man with batman for better colourized manpages
    man = "batman";

    # Restart display manager
    restart-gui = "sudo systemctl restart display-manager";


    # ---------- NixOS rebuild commands ----------
    #
    # Use nix-test after editing configuration.nix.
    # It temporarily activates the result without making
    # it the permanent boot generation.

    nix-test =
      "sudo nixos-rebuild test --flake /etc/nixos#nixos";

    # Use nix-switch after nix-test works correctly.
    # It activates the configuration permanently.
    nix-switch =
      "sudo nixos-rebuild switch --flake /etc/nixos#nixos";

    # Short alias for a normal permanent rebuild.
    nix-rebuild =
      "sudo nixos-rebuild switch --flake /etc/nixos#nixos";

    # Build the system without activating it.
    nix-build-system =
      "sudo nixos-rebuild build --flake /etc/nixos#nixos";

    # Check whether the system can build without changing
    # the currently running configuration.
    nix-build-dry =
      "sudo nixos-rebuild dry-build --flake /etc/nixos#nixos";


    # ---------- Flake update commands ----------
    #
    # Use nix-upgrade when you intentionally want to update
    # your flake inputs and rebuild the system.
    #
    # This changes /etc/nixos/flake.lock.

    nix-upgrade =
      "cd /etc/nixos && sudo nix flake update && sudo nixos-rebuild switch --flake /etc/nixos#nixos";

    # Update flake.lock without rebuilding or activating
    # the system yet.
    flake-update =
      "cd /etc/nixos && sudo nix flake update";

    # Rebuild using the exact versions already recorded
    # in flake.lock.
    nix-upgrade-locked =
      "sudo nixos-rebuild switch --flake /etc/nixos#nixos";

    # Check whether the flake structure and outputs are valid.
    nix-check =
      "sudo nix flake check /etc/nixos";

    # Show the exact versions of your flake inputs.
    nix-inputs =
      "nix flake metadata /etc/nixos";


    # ---------- NixOS generations and rollback ----------
    #
    # Use nix-generations to see older system versions
    # available for rollback.

    nix-generations =
      "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";

    # Trims the system profile down to the last 10 generations, garbage
    # collects anything now-unreachable in the store, then regenerates
    # the boot menu so it actually reflects the cleanup.  
    nix-keep-10 =
      "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +10 && sudo nix-collect-garbage && sudo nixos-rebuild boot --flake /etc/nixos#nixos";

    # Same as above, but keeps 20 generations instead of 10 —
    # a lighter cleanup for when you want more rollback headroom.
    nix-keep-20 =
      "sudo nix-env --profile /nix/var/nix/profiles/system --delete-generations +20 && sudo nix-collect-garbage && sudo nixos-rebuild boot --flake /etc/nixos#nixos";    

    # Use nix-rollback when a recent configuration causes
    # a problem and you want to return to the previous generation.
    nix-rollback =
      "sudo nixos-rebuild switch --rollback";

    # Show the system generation currently in use.
    nix-current =
      "readlink /nix/var/nix/profiles/system";


    # ---------- Nix store cleanup ----------
    #
    # Use nixdelete for normal cleanup.
    # It removes generations older than 30 days while
    # preserving recent rollback options.

    nixdelete =
      "sudo nix-collect-garbage --delete-older-than 30d";

    # Shorter alias for normal Nix garbage collection.
    nix-gc =
      "sudo nix-collect-garbage --delete-older-than 30d";

    # Use only when you are certain you no longer need
    # any old rollback generations.
    #
    # WARNING: This removes all old generations.
    nix-delete-all-old =
      "sudo nix-collect-garbage --delete-old";

    # Show how much space the Nix store is using.
    nix-store-size =
      "sudo du -sh /nix/store";

    # Manually deduplicate identical files in the Nix store.
    nix-optimize =
      "sudo nix-store --optimise";


    # ---------- Nix file commands ----------
    #
    # Use nix-format after editing configuration.nix
    # or flake.nix to keep the formatting consistent.
    #
    # Requires nixfmt in systemPackages.

    nix-format =
      "sudo nixfmt /etc/nixos/configuration.nix /etc/nixos/flake.nix";


    # ---------- Configuration Git commands ----------
    #
    # Use these commands to review and save versions
    # of your NixOS configuration.

    # Review changes to your configuration.
    config-diff =
      "cd /etc/nixos && sudo git diff";

    # Show changed and untracked files.
    config-status =
      "cd /etc/nixos && sudo git status";

    # Show your ten most recent configuration commits.
    config-log =
      "cd /etc/nixos && sudo git log --oneline --decorate -10";

    # Save the current configuration in a Git commit.
    # Git will ask you for a commit message.
    config-save =
      "cd /etc/nixos && sudo git add configuration.nix hardware-configuration.nix flake.nix flake.lock && sudo git commit";


    # ---------- System information commands ----------
    #
    # Use these for quick system, hardware, disk,
    # memory, network, and service checks.

    # Show system, CPU, GPU, memory, and kernel information.
    ff =
      "fastfetch";

    # Open an interactive resource monitor.
    bt =
      "btop";

    # Open Dank Interactive resource monitor
    dg = 
      "dgop";  

    # Show disk space usage.
    disks =
      "df -h";

    # Show memory and swap usage.
    memory =
      "free -h";

    # Show network interfaces and IP addresses.
    myip =
      "ip -brief address";

    # Show failed systemd services.
    boot-status =
      "systemctl --failed";

    # Show Secure Boot status
    sb-status = 
      "sbctl status";

    # Verify secure boot
    sb-verify =
      "sbctl verify";    
  };

  # Initialize Zsh tools when an interactive shell opens.
  interactiveShellInit = ''
    eval "$(zoxide init zsh)"
    eval "$(fzf --zsh)"
  '';
};

  # Make Zsh the default shell for users.
  users.defaultUserShell = pkgs.zsh;

  # Automatically load per-project development environments.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  
  # Enable the OpenSSH daemon
  services.openssh.enable = true;



  # ---------- Custom (non-bundled) theme setup ----------
    #
    # Uncomment this if you want a theme not shipped with Oh My Zsh,
    # e.g. powerlevel10k. Leave `theme` above unset/commented when using this.
    #
    # plugins = [
    #   {
    #     name = "powerlevel10k";
    #     src = pkgs.zsh-powerlevel10k;
    #     file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    #   }
    # ];
    #
    # Then source it so zsh actually loads it as your prompt:
    # interactiveShellInit = ''
    #   source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    # '';
  

  # ==========================================
  # System-Wide Font Configuration
  # ==========================================
  fonts = {
    # Define the list of font packages to install globally
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono   # Installs JetBrains Mono Nerd Font (provides icons for eza, bat, etc.)
      noto-fonts                  # Multilingual support (Arabic, Cyrillic, etc.)
      noto-fonts-cjk-sans         # Chinese, Japanese, Korean support
      noto-fonts-color-emoji      # Comprehensive emoji support
      symbola                     # Full Unicode symbol coverage (fixes missing squared/enclosed letters)
      freefont_ttf                # GNU FreeFont: covers mathematical bold script
      stix-two                    # STIX Two fonts: excellent math & script coverage
    ];

    # Manage how fonts are rendered and prioritized across the system
    fontconfig = {
      enable = true;
      
      # Set the fallback and default fonts for specific font families
      defaultFonts = {
        # Forces terminals (like Kitty) and code editors to default to this font 
        # whenever a "monospace" font is requested
        monospace = [ "JetBrainsMono Nerd Font" "FreeMono" "STIX Two Math" "Symbola" ];
        sansSerif = [ "Noto Sans" "FreeSans" "STIX Two Text" "Symbola" ];
        serif     = [ "Noto Serif" "FreeSerif" "STIX Two Text" "Symbola" ];
        emoji     = [ "Noto Color Emoji" ];
      };
    };
  };

  # ==========================================
  # Thunar File Manager
  # ==========================================
  programs.thunar = {
    enable = true;

    # These plugins were moved from pkgs.xfce
    # to the top-level pkgs namespace.
    plugins = [
      pkgs.thunar-archive-plugin
      pkgs.thunar-volman
      pkgs.thunar-media-tags-plugin
      pkgs.thunar-shares-plugin
    ];
  };

  # Services needed for Thunar mounting, trash,
  # removable devices, and thumbnails.
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # Saves Thunar preferences outside a full XFCE desktop session.
  programs.xfconf.enable = true;

  ##################################################
  # Hyprland Window Manager (unused)
  ##################################################
  # programs.hyprland = {
  #   enable = true;
  #   xwayland.enable = true;
  #   withUWSM = true; # Recommended session manager for Hyprland
  # };






  # ==========================================
  # System Packages & Applications
  # ==========================================
  services.hermes-agent = {
  enable = true;

  settings.model = {
    # OpenRouter is Hermes' default provider, so no base_url
    # override is needed here (unlike the Gemini native-provider
    # setup). model.default just needs OpenRouter's model slug.
    #
    # MiniMax M3 (free): 1M context, tuned for long-horizon
    # agentic work, coding, and tool use — genuinely free, not
    # a tiny trial quota like Gemini's free tier. One of the
    # top apps sending traffic to this specific model is Hermes
    # Agent itself, so it's a well-exercised pairing.
    default = "minimax/minimax-m3:free";
  };

  # OpenRouter key.
  environmentFiles = [ "/var/lib/hermes/env" ];

  addToSystemPackages = true;
 };



  # ------------------------------------------
  # Wireshark — packet capture without sudo
  # ------------------------------------------
  # The module installs wireshark AND grants your user (if in the
  # `wireshark` group) permission to capture without running as root.
  # If enabled:
  #   1. Uncomment "wireshark" in users.users.fury.extraGroups above.
  #   2. Remove `wireshark` from systemPackages (module installs it).
   programs.wireshark.enable = true;  


  # ------------------------------------------
  # Syncthing — continuous background file sync
  # ------------------------------------------
  # Runs syncthing as your user at login, auto-restarts on crash, instead
  # of you launching it manually. Check with:
  #     systemctl --user status syncthing
  # services.syncthing = {
  #   enable = true;
  #   user = "fury";              # run as your user so it syncs your files
  #   openDefaultPorts = false;   # local-network syncing needs no firewall ports
  # };  

  # ------------------------------------------
  # Ollama — always-on local LLM server
  # ------------------------------------------
  # Runs the server at boot so LM Studio / opencode / open-webui can reach
  # http://localhost:11434 without you launching anything. `package = pkgs.ollama-cuda` 
  # offloads model inference to your NVIDIA GPU instead of CPU.
  # Idle, the server consumes nearly nothing; GPU load (and heat) only
  # happens while a model is actually generating.
  # If enabled: remove `ollama` from systemPackages (module installs it).

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };  
  # Enable open-webui
  services.open-webui = {
  enable = true;
  port = 8080;
  # optional: pin package explicitly if needed
  # package = pkgs.open-webui;
};

  # GameMode can automatically adjust CPU scheduling, I/O priority, and other settings while a game is running
  programs.gamemode.enable = true;

  programs.gamescope.enable = true;

  # Enable steam
  programs.steam = {
    enable = true;
    extraCompatPackages = [
      pkgs.proton-ge-bin
    ];
  };
  
  programs.steam.remotePlay.openFirewall = true;  # Remote Play / streaming
  boot.kernel.sysctl."vm.max_map_count" = 2147483647;  # several Proton games crash without it
  hardware.xpadneo.enable = true;  # if Xbox controller over Bluetooth
    
  # Enable system-wide Firefox installation
  programs.firefox.enable = true;

  # Enable Flatpak service for running sandboxed applications
  services.flatpak.enable = true;

  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
  
    # === FIXES ===

      # Sioyek fix(kde wayland fix)
        (pkgs.symlinkJoin {
    name = "sioyek";
    paths = [ pkgs.sioyek ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/sioyek --set QT_QPA_PLATFORM xcb
    '';
    })

     
        # Upscayl fix(kde wayland fix)
         (pkgs.symlinkJoin {
       name = "upscayl";
       paths = [ pkgs.upscayl ];
       buildInputs = [ pkgs.makeWrapper ];
       postBuild = ''
         wrapProgram $out/bin/upscayl --unset NIXOS_OZONE_WL --add-flags "--ozone-platform=x11"
       '';
       })
        # Vesktop fix(kde wayland fix)
       (pkgs.symlinkJoin {
    name = "vesktop";
    paths = [ pkgs.vesktop ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/vesktop \
        --unset NIXOS_OZONE_WL \
        --add-flags "--ozone-platform=x11"
    '';
    })
    
  





    # === SYSTEM & HARDWARE UTILITIES ===
    sbctl                  # Secure Boot key manager
    solaar                 # Logitech device manager (if you use Logitech peripherals)
    lshw                   # Hardware configuration list tool
    pciutils               # PCI bus utilities (lspci)
    usbutils               # USB device utilities (lsusb)
    smartmontools          # S.M.A.R.T. disk monitoring
    gsmartcontrol          # GUI for smartmontools
    winboat                # Run Windows apps on Linux with seamless integration


    # === SYSTEM MONITORING ===
    topgrade               # System upgrade utility
    fastfetch              # System information fetcher
    btop                   # Command-line resource monitor
    mission-center         # Beautiful system resource monitor
    cpu-x                  # System profiler and monitor (CPU-Z alternative)
    hardinfo2              # Hardware analyzer and benchmark tool
    nvitop                 # Interactive NVIDIA GPU resource monitor
    dgop                   # Go dependency graph tool
    gdu                    # gnomes Disk usage analyzer


    # === WAYLAND & DESKTOP UTILITIES ===
    kitty                  # Fast, feature-rich, GPU-based terminal
    wl-clipboard           # Wayland clipboard CLI tools (wl-copy / wl-paste)
    cliphist               # Clipboard history manager for Wayland
    flameshot              # Advanced screenshot with annotation
    qalculate-qt           # Powerful and easy to use multi-purpose desktop calculator
    hyprcursor             # new cursor theme format that has many advantages over the widely used xcursor. 
    cmatrix                # Emulate the matrix code in your terminal   


    # === CLI UTILITIES & REPLACEMENTS ===
    ripgrep                # Faster grep (rg)
    bat-extras.batman      # Read system manual pages (man) using bat as the manual page formatter
    zsh-completions        # Additional completion definitions for zsh
    util-linux             # Set of system utilities for Linux (keep for batman)
    fd                     # Faster find
    bat                    # Better cat with syntax highlighting
    eza                    # Better ls with icons (works with your Nerd Font)
    fzf                    # Fuzzy finder - extremely useful
    zoxide                 # Smarter cd command
    tealdeer               # Simplified man pages in Rust
    manix                  # Fast CLI documentation searcher for Nix
    wikiman                # Offline search engine for manual pages and other documentation
    micro                  # Modern and intuitive terminal-based text editor
    fresh-editor           # A powerful terminal text editor and IDE
    jq                     # JSON processor for CLI
    yq                     # YAML processor for CLI


    # === DEVELOPMENT & IT TOOLS ===
    vscodium               # Open source binaries of VS Code
    antigravity-fhs        # Agentic development platform
    home-manager           # home-manager for nix files
    nixfmt                 # Classic Nix Formatter
    nil                    # Yet another language server for Nix (mainly for fresh editor)
    nixd                   # Feature-rich Nix language server interoperating with C++ nix
    git                    # Version control (essential)
    gh                     # GitHub CLI tool
    gitkraken              # More polished Git GUI (requires allowUnfree) OR gitg

  # nh                     # Nix CLI helper ( enabled as module)


    # === AI TOOLS ===
    lmstudio               # LM Studio is an easy to use desktop app for experimenting with local and open-source Large Language Models (LLMs)
    cherry-studio          # Chinese Desktop client that supports for multiple LLM providers (electron eol)
    opencode               # AI coding agent built for the terminal
    opencode-desktop       # AI coding agent desktop client

  # ollama                 # Get up and running with large language models locally  ( enabled as module)
  # t3code                 # Minimal web GUI for coding agents ( in alpha not worth)  
  # llmfit                 # TUI to find LLM models right sized for the system's RAM, CPU, and GPU (using unstable version currently)
  # open-webui             # Comprehensive suite for LLMs with a user-friendly WebUI ( enabled as module)





    # Language Toolchains & Compilers
    gcc                    # GNU Compiler Collection for C/C++
    gdb                    # GNU Debugger for C/C++
    gnumake                # GNU Make build automation tool
    cmake                  # Cross-platform build generator
    go                     # Go programming language compiler & toolchain
    rustup                 # Rust toolchain manager (installs rustc & cargo)
    python3                # Python runtime
    nodejs_22              # Node.js runtime
    python3Packages.pip    # Package installer for Python
    lua                    # Lua programming language interpreter
    luarocks               # Package manager for Lua

    # Environments & Containers
    distrobox              # Wrapper to run Linux distributions in containers
    bruno                  # Open source offline Postman alternative
    devenv                 # Per-project dev environments (pairs with flakes)

  # direnv                 # Auto-load environment variables per directory ( enabled as module)
  # docker                 # Container runtime ( enabled as module)
  # docker-compose         # Multi-container orchestration ( enabled as module)


    # === NETWORK & SECURITY ===
    ethtool                # ethernet checker  
    nmap                   # Network scanner
    dig                    # DNS lookup
    whois                  # Domain info
    traceroute             # Network path tool
    iperf3                 # Network speed testing between machines
    remmina                # Remote desktop client (RDP, VNC, SSH) 
    kdePackages.kleopatra  # Certificate manager and GUI for GnuPG
    gnupg                  # GNU Privacy Guard for encryption and signing
  # wireshark              # Network packet analyzer (powerful)


    # === INTERNET & COMMUNICATION ===
    brave                  # Privacy-focused web browser
    librewolf              # Custom version of Firefox focused on privacy
    vesktop                # Custom Discord client with Vencord
    stoat-desktop          # Open-Source Discord Alternative
    mailspring             # Extensible email client


    # === FILE MANAGEMENT, SYNC & ARCHIVING ===
    wget                   # File downloader
    curl                   # HTTP Swiss army knife
    aria2                  # Fast multi-connection downloader
    qbittorrent            # Best torrent client with GUI
    filezilla              # FTP/SFTP GUI client
    syncthing              # Peer to peer file syncing across devices
    localsend              # AirDrop equivalent for local network file sharing

  
    # Backend engines ark needs to handle all formats
    unzip                  # Extract ZIP archives
    unrar                  # Extract RAR archives
    p7zip                  # Extract 7z archives
    zip                    # Create ZIP archives
    gzip                   # GNU zip compression
    xz                     # XZ compression
    zstd                   # Zstandard real-time compression
    bzip2                  # Block-sorting file compressor


    # === OFFICE & PRODUCTIVITY ===
    obsidian                  # Knowledge base and markdown note-taking
    logseq                    # Open source obsidian
    anytype                   # Offline-first, encrypted personal knowledge base and modular workspace
    appflowy                  # Open-Source notion
    onlyoffice-desktopeditors # Comprehensive office suite
    sioyek                    # PDF viewer designed for reading research papers
    pdfarranger               # Tool for merging, splitting, and rotating 
    

    # === GRAPHICS & DESIGN ===
    gimp                      # GNU Image Manipulation Program
    inkscape                  # Vector graphics editor
    krita                     # Digital painting and 2D animation
    darktable                 # Photography workflow application and RAW developer
    upscayl                   # Free and open-source AI image upscaler

    # ----------------------------------------------------------------------------


    # === GAMING & CHESS ===
    en-croissant              # Open-source Ultimate Chess Toolkit
    pawn-appetit              # Ultimate Chess Toolkit (fork of en-croissant)
    prismlauncher             # Free, open source launcher for Minecraft
    heroic                    # Native GOG, Epic, and Amazon Games Launcher for Linux
    bottles                   # Wine prefix manager for running Windows software

    # Gaming performance and diagnostics
    mangohud
    vulkan-tools
    mesa-demos

    # Wine/Proton helpers
    protontricks
    protonup-qt
    winetricks
    wineWow64Packages.stable



    # === MEDIA, AUDIO & VIDEO ===
    mpv                       # Highly configurable command-line video player
    haruna                    # Open source video player built with Qt/QML and libmpv
    vlc                       # Versatile cross-platform media player
    nomacs                    # open source image viewer
    kdePackages.kdenlive      # Non-linear video editor for KDE
    ffmpeg-full               # Complete solution to record, convert, and stream audio/video
    mediainfo                 # Command-line utility for media file information
    mediainfo-gui             # GUI for mediainfo
    easyeffects               # Audio effects for PipeWire applications



    # === KDE EXTRAS ===
    kdePackages.sddm-kcm      # Login screen manager
    kdePackages.kcalc         # Calculator offering everything a scientific calculator does, and more


    # === THEMES & CURSORS ===
      chicago95               # Windows 95 total-conversion theme (GTK, icons, XFWM) for XFCE
      gtk-engine-murrine      # GTK2 rendering engine — needed for Chicago95 to draw correctly in older GTK2 apps
      google-cursor           # Opensource cursor theme inspired by Google
      bibata-cursors          # Modern triangular cursor



    # === Chicago95 taskbar plugins === 

    # The Win95 taskbar look: Whisker Menu is the "Start" button (the theme
    # ships Win95-logo sidebar branding for it), and these are the plugins
    # the Chicago95 panel layout uses. Added to your EXISTING
    # environment.systemPackages list.
    #   xfce4-whiskermenu-plugin  → Start button
    #   xfce4-panel-profiles      → applies the official Win95 taskbar layout
    #   xfce4-clipman-plugin      → clipboard history, retro-fitting
    #   xfce4-docklike-plugin     → optional Win95 quick-launch style
     pkgs.xfce4-whiskermenu-plugin
     pkgs.xfce4-panel-profiles
     pkgs.xfce4-clipman-plugin
     pkgs.xfce4-docklike-plugin

     # --- Chicago95 extras ---

     # Authentic MS Sans Serif look: cronyx-cyrillic provides the pixelated
     # bitmap "Helvetica" the Win95 UI actually used (upstream docs install
     # this same font from the theme repo — nixpkgs has it packaged).
     # NixOS blocks bitmap fonts by default; the option below re-enables
     # them (harmless for Plasma — it only ALLOWS bitmap fonts, never
     # changes any default font).
     font-cronyx-cyrillic

     # sox (`play` command) — needed for the Windows 95 startup chime
     # autostart entry and for testing event sounds.
     sox
    
    
    
    # Thumbnail Support Packages
    kdePackages.kdegraphics-thumbnailers # PDFs and EPS files
    kdePackages.ffmpegthumbs             # Video thumbnails
    kdePackages.kimageformats            # Advanced image formats (WebP, RAW, etc.)
    kdePackages.kio-extras               # Network shares and additional formats
    epub-thumbnailer                     # EPub book thumbnails


    # These packages come from nixos-unstable.
    #### unstablePkgs.some-package

    unstablePkgs.llmfit                 # llmfit unstable pkgs
    

  ];

  # ==========================================
  # System State Version
  # ==========================================
  # This value determines the NixOS release from which the default settings 
  # for stateful data were taken. Leave this at the release version of your first install.
  system.stateVersion = "26.05"; 









  ##################################################
  # Old Changes (unused)
  ##################################################



  ##################################################
  # Old Ethernet EEE udev Rule (unused)
  ##################################################
  # Replaced by the systemd oneshot service
  # "disable-realtek-eee" in the Systemd & System
  # Services section above, which has better timing
  # and logging.
  #
  # services.udev.extraRules = ''
  #   ACTION=="add", SUBSYSTEM=="net", KERNELS=="0000:05:00.0", RUN+="${pkgs.ethtool}/bin/ethtool --set-eee enp5s0 eee off"
  # '';

  # ------------------------------------------
  # Optional Fallback — ASPM Disable
  # ------------------------------------------
  # Only enable this if disabling EEE above does NOT fully fix
  # the disconnects. Some RTL8111 boards also have issues with
  # PCIe Active State Power Management (ASPM) causing similar
  # link renegotiation. This has a minor tradeoff: slightly
  # higher idle power draw. Uncomment only if needed.

  # boot.kernelParams = [ "pcie_aspm=off" ];





  ##################################################
  # Old XDG Desktop Portals Configuration (unused)
  ##################################################
  # This is the previous portal configuration.
  # It is preserved for reference but is not active.
  #
  # xdg.portal = {
  #   enable = true;
  #
  #   extraPortals = [
  #     pkgs.xdg-desktop-portal-gtk
  #     pkgs.xdg-desktop-portal-hyprland
  #     pkgs.kdePackages.xdg-desktop-portal-kde
  #   ];
  #
  #   config.common.default = "gtk";
  # };




  ####################################################
  # OLD WAY (unused) — manual binfmt_misc registration
  ####################################################
  # This is the old, manual way of doing it: hand-writing the magic
  # number/mask for the ELF+"AI"+0x02 signature and pointing binfmt
  # at appimage-run yourself. Superseded by the programs.appimage
  # module, which does the same registration internally and
  # is what the NixOS wiki now recommends.
  #
  # boot.binfmt.registrations.appimage = {
  #   wrapInterpreterInShell = false;
  #   interpreter = "${pkgs.appimage-run}/bin/appimage-run";
  #   recognitionType = "magic";
  #   offset = 0;
  #   mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
  #   magicOrExtension = ''\x7fELF....AI\x02'';
  # };




  ##########################################################################
  # OLD WAY (unused) - Prevent NetworkManager from injecting router DHCP DNS servers.
  # Forces all DNS queries to stay exclusively on global Quad9 DoT,
  # preventing intermittent DNS timeouts that cause Discord "no route" drops.(old)
  #################################################################################
  #networking.networkmanager.settings = {
   # "ipv4" = {
   #   "ignore-auto-dns" = true;
   # };
   # "ipv6" = {
   #  "ignore-auto-dns" = true;
   # };
   # };
# -----------------------------------------------------------------------------------------------------------------------------------------------------------------

   #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ 
   # things to implement in future if needed
   #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


  # ------------------------------------------
  # Optional — Encrypted Disk Swap (currently NOT enabled; swap works fine as-is)
  # ------------------------------------------
  # Current setup: zram swap (compressed RAM, priority 5) + a 9GB disk
  # partition (priority -2). zram handles ~99% of swap activity; the disk
  # partition only catches rare overflow.
  #
  # randomEncryption scrambles the disk swap with a fresh random key every
  # boot, so its contents can never be read after shutdown (no plaintext
  # memory pages on disk). HOWEVER, it BREAKS HIBERNATION — the
  # hibernation image is written to disk swap and the key is gone on
  # reboot, so resume becomes impossible. Never combine the two.
  #
  # This lives in hardware-configuration.nix (swapDevices is declared
  # there), not here. Would be:
  #   swapDevices = [
  #     { device = "/dev/disk/by-uuid/25c2c9f4-c6c6-4c26-a611-fd61ba5efa21";
  #       randomEncryption.enable = true; }
  #   ];
  # (Leave zramSwap alone — zram never touches disk.)

  # ------------------------------------------
  # Optional — Hibernation (suspend-to-disk)
  # ------------------------------------------
  # Powers the machine fully OFF while saving RAM contents to disk swap.
  # Uses ~0W unlike sleep, which still draws power.
  #
  # The kernel hibernates into the swap device with the HIGHEST priority.
  # Your zram is priority 5, disk swap -2, so the kernel would try to
  # hibernate into RAM (nonsense). For hibernation you must flip which
  # is higher:
  #   1. In hardware-configuration.nix, give disk swap priority 10:
  #        swapDevices = [
  #          { device = "/dev/disk/by-uuid/25c2c..."; priority = 10; }
  #        ];
  #   2. Here, keep zram below it:
  #        zramSwap.priority = 1;
  #   3. Tell the kernel where to resume from — add to the existing
  #      boot.kernelParams line (which already has "pcie_aspm=off"):
  #        boot.kernelParams = [ "pcie_aspm=off"
  #          "resume=UUID=25c2c9f4-c6c6-4c26-a611-fd61ba5efa21" ];
  #      And set the resume device:
  #        boot.resumeDevice = "/dev/disk/by-uuid/25c2c9f4-c6c6-4c26-a611-fd61ba5efa21";




  # ==========================================
  # Performance & Maintenance (optional)
  # ==========================================

  # ------------------------------------------
  # scx — sched_ext userspace CPU scheduler
  # ------------------------------------------
  # sched_ext lets CPU scheduling policy run in userspace (your 6.18
  # kernel supports it). The "scx_lavd" policy is tuned for
  # interactive/gaming responsiveness: under heavy load, your foreground
  # apps and games keep snappy frame pacing instead of competing equally
  # with background compiles, backups, and browser tabs.
  #
  # ⚠️ HEAT NOTE: a different scheduler changes WHEN CPU work runs, which
  # can shift thermal behavior on a CPU that already runs slightly warm
  # (your Ryzen 5 3600). If you enable this, compare temps with `btop`
  # before/after under the same workload. If temps or fan noise go UP,
  # comment it back out and rebuild — that's the entire rollback.
  # No package changes needed — the module installs its own tooling.
  # services.scx = {
  #   enable = true;
  #   scheduler = "scx_lavd";
  # };













}