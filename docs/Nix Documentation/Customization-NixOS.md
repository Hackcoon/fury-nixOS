# Customizing NixOS

An exhaustive, independently-usable reference for customizing every visible and invisible part of NixOS — boot, console, fonts, login screen, desktop, themes, shells, prompts, and the system identity. Every code block is self-contained and copy-pasteable into your `configuration.nix` or a module, with inline comments explaining what each line does.

**Sources synthesized:** NixOS Manual · NixOS Options Search · nixpkgs module sources (`config/fonts/*`, `services/display-managers/sddm.nix`, `programs/dconf.nix`, `programs/zsh/*`, `i18n/input-method/*`, `console.nix`) · KDE / GTK / Qt upstream docs · Home Manager manual (for user-level variants). Schema verified against nixpkgs release-26.05 — marked **[SCHEMA]** where options are version-sensitive; always cross-check <https://search.nixos.org/options> before adopting.

**Scope note:** this guide is system-level (`configuration.nix`). User-level equivalents (per-user themes, dotfiles) belong to Home Manager — the same options often exist as `home.file`, `dconf.settings`, `programs.zsh.*` there. Where the pattern differs meaningfully, a note says so.

---

## Table of Contents

1. [System Identity & Branding](#1-system-identity-branding)
2. [Boot Loader & Plymouth (the boot screen)](#2-boot-loader-plymouth-the-boot-screen)
3. [Linux Console (TTY)](#3-linux-console-tty)
4. [Fonts](#4-fonts)
5. [Login Screen — SDDM (themes, Wayland, autologin)](#5-login-screen-sddm)
6. [KDE Plasma Customization](#6-kde-plasma-customization)
7. [GTK / Qt Theming (system-wide)](#7-gtk-qt-theming)
8. [Cursors, Icons, Sounds](#8-cursors-icons-sounds)
9. [Shells — Zsh, Bash, Fish (+ Oh-My-Zsh, prompts)](#9-shells)
10. [Starship / Custom Prompts](#10-starship-custom-prompts)
11. [Input Methods (fcitx5 for CJK)](#11-input-methods-fcitx5)
12. [Environment Variables & Session Tweaks](#12-environment-variables-session-tweaks)
13. [Nix & Rebuild UX (nh, nix-darwin-style quality of life)](#13-nix-rebuild-ux)
14. [Miscellaneous Polish](#14-miscellaneous-polish)
15. [Troubleshooting Customization](#15-troubleshooting-customization)
16. [Vendor Display + Fonts Rename + AutoLogin + HiDPI + GTK4/Qt6 + SDDM Wayland](#16-vendor-display-fonts-rename-autologin-hidpi-gtk4qt6-sddm-wayland)
17. [Reference Index](#17-reference-index)

---

## 1. System Identity & Branding

```nix
{ config, pkgs, ... }: {
  # The hostname — shows in prompts, KDE info center, network:
  networking.hostName = "fury-os";

  # A short description shown in `nixos-version` and the boot menu entries:
  # (system.nixos.label is derived; description is free-form)
  system.nixos.tags = [ "fury" "custom" ];  # appended to boot entries

  # /etc/issue — the text printed on a TTY login prompt:
  environment.etc."issue".text = ''
    Welcome to FuryOS — Unauthorized access will be prosecuted.
  '';

  # /etc/motd — shown after a successful TTY/SSH login:
  environment.etc."motd".text = ''
    ████  NixOS 26.05  ████
    Type `nixos-help` for the manual.
  '';
}
```

## 2. Boot Loader & Plymouth (the boot screen)

### 2.1 Plymouth — the animated splash

```nix
{ config, pkgs, ... }: {
  # Plymouth hides the boot text behind an animation. Works with
  # systemd-boot AND lanzaboote/secure-boot setups.
  boot.plymouth = {
    enable = true;

    # Themes: bgrt (vendor logo, default), fade-in, spin, solar, ...
    # List installed ones: ls $(nix-build '<nixpkgs>' -A plymouth)/share/plymouth/themes/
    theme = "bgrt";

    # Overrides; e.g. to force a custom theme from a package:
    # themePackages = [ pkgs.adi1090x-plymouth-themes ];
  };

  # HIDE the boot text entirely (silent boot). Combine with plymouth
  # for a clean vendor-logo → login flow:
  boot.kernelParams = [ "quiet" "loglevel=3" ];
  # "quiet"     → suppress most kernel messages
  # "loglevel=3"→ only errors (and worse) reach the console
  # Add "udev.log_level=3" for total silence on newer systems:
  # boot.kernelParams = [ "quiet" "loglevel=3" "udev.log_level=3" ];
}
```

### 2.2 systemd-boot menu styling

```nix
{ config, pkgs, ... }: {
  # Timeout before default entry boots (seconds). 0 = instant boot,
  # menu accessible only by holding a key at power-on:
  boot.loader.timeout = 1;

  # systemd-boot does not support background images. It's intentionally
  # minimal. Entries can be named though:
  boot.loader.systemd-boot.configurationLimit = 10;  # keep 10 generations bootable

  # To make it prettier: bump console resolution (affects TTY too):
  boot.loader.systemd-boot.consoleMode = "max";  # native display resolution
}
```

> **GRUB users:** `boot.loader.grub.splashImage`, `grub.theme` (e.g. `pkgs.grub2/themes/vimix` or fetch FromGitHub), and `grub.gfxmodeEfi = "2560x1440x32"` — full theming is possible, unlike systemd-boot.

## 3. Linux Console (TTY)

The text-mode console (Ctrl+Alt+F2) — font, keymap, colors:

```nix
{ config, pkgs, ... }: {
  # Keymap for both XKB-capable sessions AND the raw console:
  console.keyMap = "us";

  # Console font — matters on HiDPI, since the default is tiny:
  console.font = "ter-v32n";   # terminus 32pt normal
  console.packages = [ pkgs.terminus_font ];  # the font's package

  # Early KMS so the console switches to native resolution immediately
  # (requires the GPU driver loadable in initrd; your hardware-configuration
  # may already contain the right line — check before adding):
  # boot.initrd.kernelModules = [ "amdgpu" ];     # AMD
  # boot.initrd.kernelModules = [ "i915" ];        # Intel
  # boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_drm" ];  # NVIDIA (see caveats)
  # ...with NVIDIA also set modeset:
  # boot.kernelParams = [ "nvidia_drm.modeset=1" ];
}
```

## 4. Fonts

```nix
{ config, pkgs, ... }: {
  # Base set — good Unicode coverage (default fonts module):
  fonts.enableDefaultPackages = true;

  # Your actual font stack. Every visible family you want available:
  fonts.packages = with pkgs; [
    # ---- UI / body fonts --------------------------------------------
    inter            # modern geometric UI font
    noto-fonts       # huge Unicode coverage (Google Noto base)
    noto-fonts-cjk-sans    # Chinese/Japanese/Korean sans
    noto-fonts-emoji       # full-color emoji

    # ---- Monospace (terminal, code) ---------------------------------
    jetbrains-mono
    nerd-fonts.jetbrains-mono  # patched with icons (nerdfonts.override{fonts} removed)
    # ↑ ONE nerd-fonts package, not many — avoids several GiB of duplicates.

    # ---- Windows web compat (EULA-restricted) -----------------------
    corefonts         # Arial, Times New Roman, Verdana... (unfree)

    # ---- Coding-ligature alternative --------------------------------
    fira-code
  ];

  # Default fallback when a glyph is missing (prevents tofu boxes):
  fonts.fontconfig.defaultFonts = {
    monospace = [ "JetBrainsMono Nerd Font" "Noto Fonts Mono" ];
    sansSerif = [ "Inter" "Noto Sans" ];
    serif    = [ "Noto Serif" ];
    emoji    = [ "Noto Color Emoji" ];
  };

  # Subpixel rendering hinting for LCD panels (sharp text):
  fonts.fontconfig.subpixel.rgba = "rgb";

  nixpkgs.config.allowUnfree = true;  # for corefonts
}
```

## 5. Login Screen — SDDM

The KDE default greeter; the most customizable login manager on NixOS.

```nix
{ config, pkgs, lib, ... }: {
  services.displayManager.sddm = {
    enable = true;

    # Run the greeter itself on Wayland (crisper, no X11 dependency):
    wayland.enable = true;

    # The theme = a *path* to a theme dir. Most themes ship as packages:
    # NOTE [SCHEMA]: theme takes the share/sddm/themes/<name> path.
    theme = "${pkgs.kdePackages.sddm-kde}/share/sddm/themes/breeze";

    # Theme dependencies (Qt plugins the theme needs to render):
    extraPackages = with pkgs; [
      kdePackages.qtsvg          # SVG assets in themes
      kdePackages.qtmultimedia   # video backgrounds
      where-is-my-sddm-theme     # example popular theme package
    ];

    # Numeric lock ON at the password prompt:
    autoNumlock = true;

    # Custom setup script run inside the greeter session before the
    # login UI — e.g. fix DPI, set cursor theme for the greeter:
    setupScript = ''
      # Runs as root before the greeter starts. Example: scale HiDPI:
      # export QT_SCALE_FACTOR=1.5
      echo "SDDM greeter starting on $(date)" >> /var/log/sddm-setup.log
    '';

    # Low-level sddm.conf overrides (settings not yet surfaced as options):
    settings = {
      General = {
        # Users with UID below this are hidden from the user list:
        MinimumUid = "1000";
        # Remember last logged-in user:
        RememberLastUser = true;
        # Halt/restart buttons on the greeter:
        HaltCommand = "/run/current-system/sw/bin/systemctl poweroff";
        RebootCommand = "/run/current-system/sw/bin/systemctl reboot";
      };
      Theme = {
        # Cursor used on the greeter:
        CursorTheme = "GoogleDot-Black";
        # Cursor size:
        CursorSize = "24";
      };
      Users = {
        # Hide specific users from the avatar list (comma-separated string, not list):
        HiddenUsers = "nobody";
      };
      Autologin = {
        # AUTOLOGIN (no password at boot) — the classic dual-edged sword:
        # User = "fury";
        # Session = "plasma";      # desktop session id to auto-start
        # Relogin = false;         # don't relogin on logout (safe default)
      };
    };
  };

  # A theme from a flake (e.g. your qylock/sddm theme) is equally valid:
  # theme = "${qylock.packages.${system}.default}/share/sddm/themes/qylock";
}
```

> **Qylock note:** your flake already wires `programs.qylock` — that module composes with the options above (it registers its own themes). Set `theme` here if you want to override which one SDDM loads by default.

> **Other greeters:** `services.displayManager.gdm.enable` (GNOME, less themable), `services.greetd` (minimal, pairs with `programs.regreet` — a slick GTK greeter), `services.displayManager.lightdm` (+ `lightdm.greeters.enso`, `greeters.slick`…).

## 6. KDE Plasma Customization

### 6.1 The desktop itself

```nix
{ config, pkgs, ... }: {
  services.desktopManager.plasma6.enable = true;

  # System-wide KDE settings via kwriteconfig-style declarations.
  # These write into the user's plasma configs at login time (mutable
  # layer). Everything configurable in System Settings has a key here:
  #   discover keys with: kreadconfig5/6 --file <config> --group <grp>
  # or by diffing ~/.config after changing something in System Settings.
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    konsole          # if you use kitty/alacritty instead
    elisa            # KDE music player
    kate             # editor (keep if you like it)
  ];

  # Enable KDE Connect (phone integration) system-wide:
  programs.kdeconnect.enable = true;
}
```

### 6.2 The colorscheme file approach

```nix
{ config, pkgs, ... }: {
  # Plasma reads a .colors file for the global theme. You already have
  # DarkDream.colors — place it declaratively:
  environment.etc."xdg/plasma/local.d/DarkDream.colors".source =
    ./assets/DarkDream.colors;   # relative to this nix file

  # and set it active for new users / default profile:
  environment.variables = {
    # Not officially needed; Plasma picks per-user. To force system-wide
    # default for all NEW accounts, use a plasma settings drop-in:
    # (see 6.3 for the dconf-equivalent for KDE: ~/.config plasma files)
  };
}
```

### 6.3 KDE per-user settings done declaratively (home-manager style)

KDE settings live in `~/.config` as INI files. Two clean ways to pin them on NixOS without Home Manager:

```nix
{ config, pkgs, ... }: {
  # Option A — write via environment.etc to /etc/xdg (system defaults
  # that per-user files override). Good for org-wide defaults:
  environment.etc."xdg/kcminputrc".text = ''
    [Mouse]
    cursorTheme=GoogleDot-Black
    [Keyboard]
    NumLock=0
  '';

  # Option B — systemd-tmpfiles to seed a user's config ONCE (idempotent,
  # doesn't fight manual edits afterward):
  systemd.tmpfiles.rules = [
    # Only create if absent ('C' = copy once):
    "C /home/fury/.config/kcminputrc - - - - ${./assets/kcminputrc}"
    "C /home/fury/.config/kglobalshortcutsrc - - - - ${./assets/kglobalshortcutsrc}"
    # Your flameshot shortcut export (kksrc) — import via KDE settings UI
    # once, or place as a file to import manually:
  ];
}
```

### 6.4 KDE panel/widgets (KWallet, Baloo, KRunner)

```nix
{ ... }: {
  # Password manager daemon — with the blowfish→gpg backend for SSH keys:
  security.pam.services.kwallet.enable = true;   # auto-unlock on login
  # [SCHEMA] on some releases this is services.kwalletd... — check search.nixos.org

  # Disable Baloo file indexing (saves IO; you lose KDE search):
  # (user-level: balooctl6 suspend && balooctl6 disable
  #  — no system option exists; it's per-user state)

  # KRunner search sources, Alt+Space alternatives etc. are per-user
  # INI files — same Option A/B pattern from 6.3.
}
```

## 7. GTK / Qt Theming

```nix
{ config, pkgs, ... }: {
  # ---- Apply a GTK theme for every user, headless apps included -----
  # Curated themes exist as packages; see pkgs/top-level/all-packages.nix
  # under "GTK themes" (or: nix search nixpkgs "gtk-theme"):
  environment.systemPackages = with pkgs; [
    adwaita-gtk-theme   # or: orchis-theme, graphite-gtk-theme, ...
  ];
  # The *active* theme for GTK apps is chosen per-user in
  # ~/.config/gtk-3.0/settings.ini — pin it system-wide like this:
  environment.etc."xdg/gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=Adwaita-dark
    gtk-icon-theme-name=Papirus-Dark
    gtk-cursor-theme-name=GoogleDot-Black
    gtk-font-name=Inter 10
  '';
  environment.etc."xdg/gtk-4.0/settings.ini".text = ''
    [Settings]
    gtk-theme-name=Adwaita-dark
    gtk-icon-theme-name=Papirus-Dark
    gtk-application-prefer-dark-theme=true
  '';

  # ---- Force Qt apps onto the same dark path ------------------------
  # When mixing Qt+GTK apps, unify the look:
  qt = {
    enable = true;                   # pulls in theming infra
    platformTheme.name = "kde";      # follow KDE settings (Plasma)
    # alternatives: "gtk2" (follow GTK), "gnome", "lxqt"...
    style.name = "breeze-dark";      # widget style for pure-Qt apps
  };
}
```

## 8. Cursors, Icons, Sounds

```nix
{ config, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    google-cursor          # provides GoogleDot-Black etc.
    papirus-icon-theme     # icon theme
  ];

  # Global cursor variables (applies to X11, Wayland fallback and GTK):
  environment.variables = {
    XCURSOR_THEME = "GoogleDot-Black";
    XCURSOR_SIZE  = "24";        # 24/32/48/64 for HiDPI: 36+
  };

  # Icons + cursor active everywhere — also set the dconf layer for
  # GNOME/GTK apps that ignore env vars (see §12 for why both):
  programs.dconf = {
    enable = true;
    # System-wide dconf *lockdown* would go to `locks`; for plain
    # defaults, GNOME reads /etc/dconf/db — NixOS generates it from
    # this profiles option:
    profiles.user.databases = [{
      settings = {
        "org/gnome/desktop/interface" = {
          cursor-theme = "GoogleDot-Black";
          icon-theme   = "Papirus-Dark";
          gtk-theme    = "Adwaita-dark";
        };
      };
    }];
  };
}
```

## 9. Shells

### 9.1 Zsh (your current shell)

```nix
{ config, pkgs, lib, ... }: {
  programs.zsh = {
    enable = true;

    # The interactive shell in nixos — per-user via users.users.<name>.shell
    # (set it there: shell = pkgs.zsh; — needed even with enable here)

    enableCompletion = true;         # tab completion (compinit)
    autosuggestions.enable = true;   # gray ghost-text of history
    syntaxHighlighting.enable = true;# command coloring as you type
    # ↑ hugely valuable: catch typos before running (red = command not found)

    # History tuning — big shared memory, no duplicates:
    interactiveShellInit = ''
      # history file & size
      HISTFILE="$HOME/.zsh_history"
      HISTSIZE=100000
      SAVEHIST=100000
      setopt SHARE_HISTORY          # all shells share history live
      setopt HIST_IGNORE_ALL_DUPS   # skip consecutive & global dups
      setopt HIST_REDUCE_BLANKS     # squeeze extra spaces
      setopt AUTO_CD                # '..' alone cd's to parent
    '';

    shellInit = ''
      # runs for EVERY zsh (including scripts) — keep minimal
    '';

    # Oh-My-Zsh if you want the framework (you use af-magic via it):
    ohMyZsh = {
      enable = true;
      # must be a theme bundled in oh-my-zsh:
      theme = "af-magic";
      plugins = [
        "git"             # git aliases & prompt info
        "extract"         # `x` extracts any archive
        "sudo"            # ESC ESC re-runs with sudo
        "command-not-found"  # suggests the nix package to install
      ];
      # Your custom theme (not bundled) — place the file & point here:
      # custom = "$HOME/.config/zsh/custom";
    };

    # Give interactive shells your aliases globally:
    shellAliases = {
      rebuild  = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      nixgrep  = "nix search nixpkgs";
      ls       = "eza --icons --group-directories-first";   # if you add eza
      update   = "sudo nix flake update --flake /etc/nixos && rebuild";
    };
  };

  # Assign the shell to the user (required!):
  users.users."fury".shell = pkgs.zsh;

  # Expose zsh completions/functions system-wide:
  environment.pathsToLink = [ "/share/zsh" ];

  # Zsh needs to be in systemPackages for login-shells from other TTs:
  environment.systemPackages = with pkgs; [ zsh ];
  # The module does this automatically when programs.zsh.enable is set;
  # the user.shell assignment is what actually changes YOUR login.
}
```

### 9.2 Fish

```nix
{ config, pkgs, ... }: {
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      # fish syntax highlighting & autosuggest are BUILT-IN (no plugins!)
      set fish_greeting ""         # no greeting line
    '';
    # fish uses "abbreviations" rather than aliases by convention:
    shellAbbrs = {
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos";
      gs = "git status";
    };
  };
}
```

### 9.3 Bash (for minimalists)

```nix
{ config, pkgs, ... }: {
  programs.bash = {
    interactiveShellInit = ''
      # modern readline behavior
      bind 'set colored-stats on'
      # history
      HISTSIZE=50000
      HISTCONTROL=ignoreboth:erasedups
      # ** expands recursively in completions:
      shopt -s globstar
    '';
    shellAliases = { rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#nixos"; };
  };
}
```

## 10. Starship / Custom Prompts

```nix
{ config, pkgs, ... }: {
  # Starship = shell-agnostic prompt (works with zsh/fish/bash).
  # Your af-magic theme and starship are alternatives — pick one.
  environment.systemPackages = with pkgs; [ starship ];

  # System-wide config for all users (each user can override in
  # ~/.config/starship.toml):
  environment.etc."starship.toml".text = ''
    # A two-line prompt with nix-shell indicator:
    add_newline = true

    [username]
    show_always = true
    style_user = "bold yellow"

    [directory]
    truncation_length = 3            # keep last 3 path components
    truncate_to_repo = true         # relative to git root

    [git_branch]
    symbol = " "                     # nerd-font icon

    [nix_shell]                      # shows when in nix-shell
    disabled = false
    symbol = " "

    [time]
    disabled = false                 # enable the timestamp
    time_format = "%T"
  '';

  # Activate for zsh (add to interactiveShellInit above, or here):
  programs.zsh.interactiveShellInit = ''
    eval "$(starship init zsh)"
  '';
}
```

## 11. Input Methods (fcitx5)

For Chinese/Japanese/Korean — or emoji input anywhere:

```nix
{ config, pkgs, ... }: {
  i18n.inputMethod = {
    # fcitx5 is the modern engine (ibus is the legacy alternative):
    enable = true;
    type = "fcitx5";

    fcitx5 = {
      addons = with pkgs; [
        fcitx5-chinese-addons   # Pinyin & table input
        # fcitx5-mozc            # Japanese
        # fcitx5-hangul          # Korean
        fcitx5-gtk              # GTK apps support
        kdePackages.fcitx5-qt   # Qt/KDE apps support
        # NOTE: no fcitx5-nerdfont package exists — removed.
      ];
      # quickphrase: typing "/" opens an emoji/symbol picker
      quickphraseOptions = ''
        /emoji=emoji.txt
      '';
    };
  };
}
```

## 12. Environment Variables & Session Tweaks

```nix
{ config, pkgs, ... }: {
  # Plain env vars for ALL sessions (systemd user environment → GUI):
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    BROWSER = "firefox";
    # Cursor (also §8 — some apps read one, some the other):
    XCURSOR_THEME = "GoogleDot-Black";
    XCURSOR_SIZE  = "24";
    # toolkit tweaks:
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";   # Qt: auto HiDPI scaling
    GDK_SCALE = "1";                     # GTK: fractional scale (2 = 200%)
  };

  # sessionVariables — same but ONLY for graphical sessions:
  environment.sessionVariables = {
    # Example: fix flatpak theming to see your theme:
    GTK_PATH = "\${ GTK_PATH }\${ GTK_PATH:+: }${pkgs.gtk3.out}/lib/gtk-3.0";
  };

  # Some packages need extra setup hooks or wrappers — prefer the
  # NixOS option when it exists (check search.nixos.org first!) before
  # falling back to environment.variables.
}
```

## 13. Nix & Rebuild UX

```nix
{ config, pkgs, ... }: {
  # nh = friendly nixos-rebuild wrapper: `nh os switch` (auto-detects
  # flake, shows diff, asks for confirmation, cleans up):
  programs.nh = {
    enable = true;
    flake = "/etc/nixos";   # required: NH_FLAKE default (your flake dir)
    # clean up old generations weekly:
    clean = {
      enable = true;
      dates = "weekly";
      # keep the last 5 and anything newer than 7 days:
      extraArgs = "--keep 5 --keep-since 7d";
    };
  };

  # Make `nixos-rebuild` print a package diff:
  environment.systemPackages = [ pkgs.nvd ];   # nvd diff /run/current-system result
}
```

## 14. Miscellaneous Polish

```nix
{ config, pkgs, ... }: {
  # ---- Faster boot ---------------------------------------------------
  # services with long start times that you don't need at boot:
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.services.systemd-udev-settle.enable = false;

  # ---- Suspend instead of poweroff on the power button --------------
  services.logind.extraConfig = ''
    HandlePowerKey=suspend
    HandleLidSwitch=suspend
  '';

  # ---- Fwupd firmware updates (nice GUI integration) ----------------
  services.fwupd.enable = true;

  # ---- Thermals/fans for AMD CPUs ------------------------------------
  # (you may already have this from the hardening guide's hardware audit)
  # services.thermald.enable = true;   # Intel
  hardware.cpu.amd.updateMicrocode = true;

  # ---- printing --------------------------------------------------------
  services.printing.enable = true;   # CUPS
  # services.printing.drivers = [ pkgs.hplip ];  # vendor drivers if needed

  # ---- greetd+regreet alternative to SDDM (minimalists) --------------
  # services.greetd = {
  #   enable = true;
  #   settings.default_session = {
  #     command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time";
  #     user = "greeter";
  #   };
  # };
}
```

## 15. Troubleshooting Customization

| Symptom | Fix |
|---|---|
| Theme applied in some apps, not others | You set the theme only via env var or only via GTK settings. Do BOTH (§7 + §8): GTK needs the INI file, Qt needs `qt.*`, X11 apps need the variable. |
| SDDM theme not found at boot | The `theme` path must exist *at boot time*, i.e. it must be in the system closure — use packages from `extraPackages` or a store path, not a `/home` path (SDDM runs before your home is mounted in some setups, and never follow symlinks out of the store). |
| SDDM shows tiny cursor / wrong theme | Set `settings.Theme.CursorTheme` (§5), ensure the cursor package is in `extraPackages` — greeter doesn't inherit your user's packages. |
| Font shows tofu boxes □□□ | The specific glyph coverage is missing. Add `noto-fonts-cjk-sans` (CJK), `noto-fonts-emoji` (emoji), or the specific script's package (§4), then `fc-cache -f` isn't needed on NixOS (fontconfig cache is per-generation) — reboot/re-login. |
| Custom zsh theme "not found" | oh-my-zsh only ships bundled themes; a custom theme file goes through `ohMyZsh.custom` pointing at a directory with `themes/af-magic.zsh-theme` in it. |
| Autologin not working | Check three things together: `services.displayManager.autoLogin.enable = true;` + `services.displayManager.autoLogin.user = "fury";` + the SDDM `Autologin.Session` you want — some releases also need the user not to have a password expiration pending. |
| `programs.zsh.ohMyZsh` plugin missing | The plugin string must match oh-my-zsh's internal names — look them up in the upstream repo, not in Nix package names. |

## 16. Vendor Display + Fonts Rename + AutoLogin + HiDPI + GTK4/Qt6 + SDDM Wayland

### 16.1 fonts.enableDefaultPackages (rename note)

```nix
{ ... }: {
  # Current (26.05): fonts.enableDefaultPackages = true;
  # Old name fonts.enableDefaultFonts was renamed — if you see
  # "unknown option enableDefaultFonts" errors, you copied a pre-24.11 snippet.
  fonts.enableDefaultPackages = true;
  fonts.enableGhostscriptFonts = false;  # true only if you want URW PostScript dupes
}
```

### 16.2 displayManager.autoLogin (the correct path)

```nix
{ config, ... }: {
  services.displayManager.autoLogin = {
    enable = true;
    user = "fury";
  };
  # SDDM Autologin.Session must ALSO match (§5 settings.Autologin) + user must
  # have no password expiry. GDM ignores SDDM theme keys — one greeter at a time.
}
```

### 16.3 Per-vendor display bits

```nix
{ config, pkgs, ... }: {
  # NVIDIA: modeset + drm fbdev (Wayland/gamescope/SDDM-Wayland need both on 545+):
  hardware.nvidia.modesetting.enable = true;  # -> nvidia-drm.modeset=1 + fbdev=1
  # AMD: FreeSync/VRR is per-display KDE setting (Display -> Adaptive Sync),
  # kernel side needs amdgpu in initrd for early KMS:
  # boot.initrd.kernelModules = [ "amdgpu" ];
  # Intel: GuC/HuC firmware (media encode + power) + PSR (panel self-refresh):
  boot.kernelParams = [
    # "i915.enable_guc=2"      # pre-Xe Intel (Alder Lake and older): GuC+HuC on
    # "xe.enable_guc=2"        # Arc/Battlemage on xe driver
    # "i915.enable_psr=1"      # PSR power-save (0 to debug flicker)
  ];
  hardware.enableRedistributableFirmware = true;  # GuC/HuC blobs come from linux-firmware
}
```

### 16.4 Cursor scaling per-HiDPI + GTK4/libadwaita + Qt6 kvantum per-DE

```nix
{ config, pkgs, ... }: {
  environment.variables = {
    XCURSOR_SIZE = "36";  # 24 @1080p, 32-36 @1440p, 48 @4K (greeter needs §5 CursorSize too)
  };
  environment.systemPackages = with pkgs; [
    adwaita-icon-theme gnome-themes-extra  # GTK4/libadwaita baseline (dark prefers-color-scheme)
    libsForQt5.qtstyleplugins kdePackages.qt6ct  # Qt5/6 config GUIs
    # kvantum: libsForQt5.qtstyleplugin-kvantum / kdePackages.qtstyleplugin-kvantum
  ];
  # Plasma: qt.platformTheme.name = "kde" follows Breeze (§7). GNOME: leave Qt on
  # adwaita-qt + kvantum theme = Kvantum. Never force QT_QPA_PLATFORMTHEME globally
  # on Plasma — it fights kde integration. Per-DE: Plasma->kde, GNOME->gtk2/gnome.
}
```

### 16.5 SDDM Wayland vs X11 per GPU vendor

```nix
{ config, ... }: {
  services.displayManager.sddm.wayland.enable = true;  # crisp greeter, no X11 dep
  # NVIDIA quirk: SDDM-Wayland + proprietary driver <535 = black greeter.
  # Fix: modesetting.enable = true + open = true (Turing+) + reboot. If still
  # black, fallback: services.displayManager.sddm.wayland.enable = false;
  # AMD/Intel: Wayland greeter just works (early KMS via initrd §3).
}
```

## 17. Reference Index

- NixOS options search: <https://search.nixos.org/options> (theme/fonts/sddm/zsh all under `programs.*`, `services.displayManager.*`, `fonts.*`)
- Home Manager (user-level customization — the natural companion): <https://nix-community.github.io/home-manager/>
- KDE config keys discovery: change something in System Settings, then `diff` `~/.config` — or use `kreadconfig6`
- SDDM themes gallery: <https://store.kde.org/browse> (SDDM section)
- Starship config docs: <https://starship.rs/config/>
- Oh-My-Zsh themes/plugins: <https://github.com/ohmyzsh/ohmyzsh/wiki>
- nixpkgs fonts module source: `nixos/modules/config/fonts/packages.nix`
- nixpkgs sddm module source: `nixos/modules/services/display-managers/sddm.nix`

Continue to: `Gaming-NixOS.md` (Steam, gamemode, gamescope, controllers, and performance for the other kind of customization — FPS).
