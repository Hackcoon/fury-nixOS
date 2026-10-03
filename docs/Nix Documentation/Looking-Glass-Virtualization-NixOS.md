# Looking Glass on NixOS — Native-Performance VM Display

An exhaustive, independently-usable reference for **Looking Glass B7** on NixOS: the low-latency bridge that lets a GPU-passthrough Windows VM render on your Linux desktop with near-zero latency — no second monitor, no KVM switch. Includes the two advanced setups people run it with: **single-GPU passthrough** and the **one-hotkey "instant Windows" launch** (start VM → detach host GPU → attach guest GPU → Looking Glass window, all automated).

**Sources synthesized:** Looking Glass B7 official documentation (requirements, IVSHMEM/KVMFR, libvirt install, client usage incl. full option table + overlay/EGL filters, host usage incl. capture interfaces + downsampling, troubleshooting, FAQ) · NixOS Wiki "Looking Glass" page (edited Feb 2026, targeting NixOS 25.11+, systemd 258+) · nixpkgs `libvirtd.nix` hooks implementation (verified release-26.05) · libvirt hooks spec (libvirt.org/hooks.html) · `pkgs/os-specific/linux/kvmfr` packaging · upstream GitHub issues #1151/#1153 (NVIDIA Wayland explicit-sync).

**Prerequisite:** a working GPU-passthrough VM per `Virtualization-NixOS.md` §9. If your GPU isn't passed through yet, go there first — Looking Glass rides on top of that.

---

## Table of Contents

1. [What Looking Glass Is & How It Works](#1-what-looking-glass-is-how-it-works)
2. [Requirements & Hardware Notes (AMD/Intel/NVIDIA)](#2-requirements-hardware-notes)
3. [Determining Shared Memory Size](#3-determining-shared-memory-size)
4. [Host NixOS Configuration (complete)](#4-host-nixos-configuration-complete)
5. [VM/libvirt XML Configuration](#5-vmlibvirt-xml-configuration)
6. [Guest (Windows) Setup — Host App + IVSHMEM Driver](#6-guest-windows-setup-host-app-ivshmem-driver)
7. [Client Usage: Keys, Overlay, Config File](#7-client-usage-keys-overlay-config-file)
8. [Performance Tuning](#8-performance-tuning)
9. [One-Key "Instant Windows" Launch (Hotkey)](#9-one-key-instant-windows-launch-hotkey)
10. [Single-GPU Passthrough (Hooks)](#10-single-gpu-passthrough-hooks)
11. [Troubleshooting](#11-troubleshooting)
12. [Reference Index](#12-reference-index)

---

## 1. What Looking Glass Is & How It Works

A passthrough VM normally needs a physical monitor plugged into the passed GPU, plus a KVM switch or second keyboard/mouse. Looking Glass removes all of it:

```
┌──────── Windows guest ─────────┐      ┌──────── Linux host ────────────┐
│ looking-glass-host.exe         │      │                               │
│   captures frames (DXGI/NvFBC) │ DMA/ │ looking-glass-client          │
│   → writes to IVSHMEM ─────────┼──────┼─ reads IVSHMEM ─→ renders on  │
│   ← SPICE channel (input) ─────┼──────┼─ keyboard/mouse → your desktop│
│   ← SPICE channel (audio) ─────┼──────┼─ PipeWire audio output         │
└────────────────────────────────┘      └───────────────────────────────┘
         IVSHMEM = a shared RAM window between guest and host
         (via /dev/kvmfr0 with the KVMFR kernel module — the fast path)
```

- **Frames out** (guest→host): the guest app grabs the GPU framebuffer and writes it into IVSHMEM shared memory. With the KVMFR kernel module and an AMD/Intel *host* GPU, this becomes a **DMA transfer handled by the host GPU itself** (DMABUF) — the CPU never copies frames.
- **Input & audio in** (host→guest): ordinary SPICE channels (virtio-serial), so your keyboard/mouse/clipboard/audio flow over the same VM.
- Result: a window on your Linux desktop that displays Windows at high FPS with a few-ms glass-to-glass latency, fullscreenable, with scroll-lock-key grabbing keyboard/mouse.

The guest OS thinks it's rendering to a real monitor (the dummy plug or a headless fake), so games run at full native GPU performance. Looking Glass is purely a "KVM over shared memory" — the VM's GPU does all the work.

## 2. Requirements & Hardware Notes

From the official B7 requirements page:

**Minimum**
- Two GPUs (any of): two dGPUs · dGPU + iGPU · GPU + vGPU
- Guest GPU must have a **physical monitor or dummy plug** attached — Windows powers down outputs with nothing connected and Looking Glass cannot capture a dead display
- CPU: 6c/12t minimum recommended; 8c/16t @ 3.0GHz+ ideal
- PCIe: both GPUs at minimum x8 (Gen3) or x4 (Gen4)

**Vendor-specific guidance (from upstream docs)**
- **AMD or Intel GPU as the host/client GPU — recommended.** Both support **DMABUF**: DMA frame transfer through the KVMFR module, offloading memory copies to the GPU. For iGPU hosts this is effectively *mandatory* for a decent experience (frees scarce RAM bandwidth).
- **NVIDIA as the guest GPU — recommended.** Upstream reports AMD guest GPUs (Polaris/Vega/Navi/BigNavi families) suffer passthrough stability issues (the AMD "reset bug" family); NVIDIA cards are the stable passthrough choice. (NVIDIA as the *host/client* GPU works, but cannot use the DMABUF fast path with the proprietary driver — it falls back to the standard memory-copy path, which is still very usable.)
- **NvFBC capture** (guest, NVIDIA pro cards only, license-restricted) is an alternative capture API — skip unless you have a Quadro/RTX pro card.

Practical combos:
| Host GPU | Guest GPU | Notes |
|---|---|---|
| AMD / Intel (iGPU or dGPU) | NVIDIA dGPU | Best case: DMABUF + stable NVIDIA guest |
| AMD / Intel | AMD | Works; watch for reset-bug family issues |
| NVIDIA | NVIDIA | Works; no DMABUF on host (copy path) |
| anything | vGPU | virtual display, dummy plug not needed |

## 3. Determining Shared Memory Size

The IVSHMEM window must hold **two frames** plus slack:

```
width × height × pixel_size × 2 = frame bytes
frame bytes / 1024 / 1024        = frame MiB
frame MiB + 10 MiB               = total MiB
```

pixel size: **4** (32-bit SDR) or **8** (HDR, which is not worth it — converted back to SDR by drivers, double bandwidth).

**Round UP to a power of two.** Oversizing gains nothing (it just pins unusable RAM):

| Resolution | SDR | HDR |
|---|---|---|
| 1920×1080 | 32 MiB | 64 MiB |
| 1920×1200 | 32 MiB | 64 MiB |
| 2560×1440 | 64 MiB | 128 MiB |
| 3840×2160 | 128 MiB | 256 MiB |

This number is used in **three places that must all agree**: the kvmfr module `static_size_mb` (§4), the QEMU `size` in bytes (§5), and the memory available to the guest app. Example throughout: **64 MiB** (1440p SDR) → QEMU size `67108864` bytes.

## 4. Host NixOS Configuration (complete)

Everything on the Linux side in one block. Comments inline:

```nix
{ config, pkgs, lib, ... }:
{
  # ==========================================================
  # 1. The KVMFR kernel module (the fast path)
  # ==========================================================
  # Creates /dev/kvmfr0 — a shared-memory device with DMA support.
  # Built automatically against your current kernel:
  boot.extraModulePackages = [ config.boot.kernelPackages.kvmfr ];

  # Load it early (before any VM could ever start) so QEMU can never
  # accidentally create /dev/kvmfr0 as a regular file:
  boot.initrd.kernelModules = [ "kvmfr" ];

  # The size MUST match §3 (power of two) and the QEMU -object size:
  boot.kernelParams = [ "kvmfr.static_size_mb=64" ];

  # ==========================================================
  # 2. Permissions on /dev/kvmfr0
  # ==========================================================
  # The client (and QEMU) need rw. uaccess TAG also grants the
  # currently-logged-in seat user access.
  # NOTE on destination: services.udev.packages only reads
  # $out/lib/udev/rules.d — that is why this uses /lib/..., not /etc.
  # (The NixOS wiki page shows /etc/... in the same slot; that path
  #  belongs under environment.etc, not udev.packages.)
  services.udev.packages = lib.singleton (pkgs.writeTextFile {
    name = "kvmfr-udev";
    text = ''
      # Looking Glass shared memory device: give the kvm group + seat user rw
      SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660", TAG+="uaccess"
    '';
    destination = "/lib/udev/rules.d/70-kvmfr.rules";
  });

  # ==========================================================
  # 3. libvirt/QEMU policy
  # ==========================================================
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;   # hooks in §9-10 perform privileged actions
      swtpm.enable = true; # Windows 11
      # QEMU must be allowed to open /dev/kvmfr0 and to escape the
      # default device cgroup + namespace policy:
      verbatimConfig = ''
        namespaces = []
        cgroup_device_acl = [
          "/dev/null", "/dev/full", "/dev/zero",
          "/dev/random", "/dev/urandom",
          "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
          "/dev/rtc", "/dev/hpet", "/dev/vfio/vfio",
          "/dev/kvmfr0"
        ]
      '';
      vhostUserPackages = [ pkgs.virtiofsd ];
    };
  };

  # ==========================================================
  # 4. The Looking Glass client
  # ==========================================================
  # B7 is packaged. Wayland/X11/PipeWire backends all enabled by default.
  environment.systemPackages = with pkgs; [
    looking-glass-client
    virt-manager
    virt-viewer
  ];

  programs.virt-manager.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  users.users."fury".extraGroups = [ "libvirtd" "wheel" ];  # + "kvm" if needed
}
```

Verify after rebuild:

```bash
# Module loaded with the right size?
sudo dmesg | grep kvmfr
# expect: kvmfr: creating 1 static devices

# Device node (note the leading 'c' — a regular file here means a VM
# started before the module; delete it and reboot):
ls -l /dev/kvmfr0
# crw-rw---- 1 root kvm 242, 0 ... /dev/kvmfr0
```

## 5. VM/libvirt XML Configuration

Edit with `virsh edit win10` (or virt-manager → XML tab). Merge the pieces you don't already have from the base guide.

### 5.1 QEMU namespace

```xml
<!-- The <domain> tag at the very top must gain the qemu: namespace
     (required for the qemu:commandline block): -->
<domain type="kvm" xmlns:qemu="http://libvirt.org/schemas/domain/qemu/1.0">
```

### 5.2 IVSHMEM device — KVMFR path (recommended)

```xml
<qemu:commandline>
  <!-- Modern syntax for QEMU ≥6.2 / libvirt ≥7.9 (true on NixOS 25.05+).
       size is in BYTES: MiB × 1024 × 1024. 64 MiB example → 67108864.
       MUST equal kvmfr.static_size_mb from §4. -->
  <qemu:arg value="-device"/>
  <qemu:arg value='{"driver":"ivshmem-plain","id":"shmem0","memdev":"looking-glass"}'/>
  <qemu:arg value="-object"/>
  <qemu:arg value='{"qom-type":"memory-backend-file","id":"looking-glass","mem-path":"/dev/kvmfr0","size":67108864,"share":true}'/>
</qemu:commandline>
```

> Alternative (no kernel module): plain shared memory at `/dev/shm/looking-glass` —
> ```xml
> <shmem name="looking-glass">
>   <model type="ivshmem-plain"/>
>   <size unit="M">64</size>
> </shmem>
> ```
> Works everywhere but loses DMA on AMD/Intel hosts. Prefer KVMFR.

### 5.3 Input, audio, video, clipboard (SPICE channels)

```xml
<!-- ================================================================
     INPUT — needed for keyboard/mouse through the client.
     (virt-manager's default <input type='tablet'/> must be REMOVED,
      it breaks 5-button mice; use these instead:)
     ================================================================ -->
<input type="mouse" bus="virtio"/>
<input type="keyboard" bus="virtio"/>

<!-- ================================================================
     VIDEO — set the emulated video to basic vga (it's only the
     fallback/BIOS display; the real GPU does the work):
     ================================================================ -->
<video>
  <model type="vga"/>
</video>

<!-- ================================================================
     AUDIO — Intel HDA piped over SPICE → your PipeWire:
     ================================================================ -->
<sound model="ich9">
  <audio id="1"/>
</sound>
<audio id="1" type="spice"/>

<!-- ================================================================
     CLIPBOARD SYNC — SPICE guest agent channel (needs virtio-win's
     spice-guest-tools in the guest, see §6. DO NOT also install
     "QEMU guest tools" — different thing, breaks this):
     ================================================================ -->
<channel type="spicevmc">
  <target type="virtio" name="com.redhat.spice.0"/>
  <address type="virtio-serial" controller="0" bus="0" port="1"/>
</channel>

<!-- Keep the SPICE graphics type (it carries input/clipboard even
     when you never open a virt-viewer window): -->
<graphics type="spice" autoport="yes"/>

<!-- And from the base guide: no memballoon (VFIO latency): -->
<memballoon model="none"/>
```

### 5.4 GPU passthrough hostdev entries

Unchanged from `Virtualization-NixOS.md` §9.3 — the passed GPU + its audio function, `managed="yes"`, with the dummy plug connected.

## 6. Guest (Windows) Setup — Host App + IVSHMEM Driver

1. **Boot the VM once with the §5 XML applied** so the IVSHMEM device and SPICE channels exist. Install drivers from **virtio-win ISO** if not done already (base guide §10): at minimum viostor (disk), netkvm (net), and **vioinput** (virtio mouse/keyboard).

2. **Install SPICE guest tools** (spice-guest-tools from spice-space.org or the virtio-win guest-tools installer) — enables clipboard sync (§5.3 channel) and better display behavior. Again: not "QEMU guest tools".

3. **Looking Glass host app** (the guest-side capture service):
   - Download `looking-glass-host-setup.exe` from <https://looking-glass.io/downloads> (B7 — still the stable channel as of 2026; dev builds are test-only). The B7 installer **includes the IVSHMEM driver** and installs it for you.
   - **Version lock: host and client versions must match exactly** (B7 host ↔ B7 client from nixpkgs). Mixing versions causes protocol/connection failures.
   - Run as **Administrator** (it installs a service + driver; the installer explains why).
   - Defaults are fine; it starts the `Looking Glass (host)` service immediately.
   - Silent install: `looking-glass-host-setup.exe /S`.

4. **Set the guest resolution/refresh** to what you'll run in the client — the capture follows the desktop. G-Sync/V-Sync in the guest: leave guest vsync OFF (LG guide's tuning; frames are shipped as fast as captured), enable the client's own sync instead (§8).

5. Reboot the guest once more. Verify in Device Manager: "IVSHMEM device" present, no yellow marks.

### Host app config file — capture interface, multi-IVSHMEM, downsampling

Optional file `C:\Program Files\Looking Glass (host)\looking-glass-host.ini` (create if absent). Three capture interfaces exist; D12 is default and fastest (upstream: faster than NvFBC with less overhead), DXGI is the automatic fallback, NvFBC is Quadro/pro-only:

```ini
[app]
capture=d12        # d12 (default) | dxgi | nvfbc
```

- D12 options: `adapter`, `output`, `trackDamage` (default on — only changed regions transfer), `downsample` (below), `HDR16to10`, `allowRGB24`. DXGI caveat: hardware-cursor games can microstutter on mouse movement (D12/NvFBC don't); most FPS titles unaffected.
- **Multiple IVSHMEM devices** (e.g. you added a second one for Scream audio — don't, see §11): devices count from PCI slot order starting at 0; LG takes the first unless told otherwise:
  ```ini
  [os]
  shmDevice=1      # use the SECOND ivshmem device
  ```
- **Downsampling** (run guest above monitor res, transfer at monitor res — saves bandwidth):
  ```ini
  [d12]            # or [dxgi] / [nvfbc] to match your capture=
  ; exact, greater-than, or comma-separated rules:
  downsample=3840x2160:1920x1080
  downsample=>1920x1080:1920x1080
  ```

### Host logs

- `%ProgramData%\Looking Glass (host)\looking-glass-host.txt` (or right-click the tray icon → Open Log File); service log `looking-glass-host-service.txt` covers start-up failures.
- Running as a service = runs as SYSTEM = realtime GPU priority (fixes capture starvation when a game eats 100% GPU) + captures the secure desktop (lock screen, UAC). Manual install/remove: `looking-glass-host.exe InstallService` / `UninstallService`.

## 7. Client Usage: Keys, Overlay, Config File

Launch:

```bash
looking-glass-client            # windowed
looking-glass-client -F         # fullscreen borderless immediately
```

**Default escape key: `ScrLk`** (hold it to see the cheat-sheet overlay):

| Key | Action |
|---|---|
| `ScrLk` | Toggle capture mode (grab keyboard/mouse) |
| `ScrLk + Q` | Quit |
| `ScrLk + F` | Fullscreen toggle |
| `ScrLk + O` | Overlay mode (settings/EGL filters/FPS graphs) |
| `ScrLk + D` | FPS display |
| `ScrLk + I` | SPICE keyboard/mouse toggle |
| `ScrLk + E` | Audio recording toggle |
| `ScrLk + R` | Rotate output 90° clockwise |
| `ScrLk + T` | Frame timing information |
| `ScrLk + V` | Video stream toggle |
| `ScrLk + N` | Night vision mode |
| `ScrLk + Insert / Del` | Mouse sensitivity up/down (capture mode) |
| `ScrLk + LWin / RWin` | Send Win key to guest |
| `ScrLk + ↑ / ↓ / M` | Volume up / down / mute |
| `ScrLk + F1..F12` | Send Ctrl+Alt+F# |

**Config files** (INI, later files override earlier):

```
/etc/looking-glass-client.ini              # system-wide
~/.looking-glass-client.ini                # legacy user
~/.config/looking-glass/client.ini         # XDG (recommended)
```

A good starter `~/.config/looking-glass/client.ini`:

```ini
[win]
fullScreen   = yes          # start fullscreen borderless
fpsMin       = -1           # auto-detect minimum frame rate
# jitRender  = yes          # render only when a new frame arrives (CPU saver)

[input]
rawMouse     = yes          # absolute-fidelity mouse in capture mode
grabKeyboard = yes
escapeKey    = 70           # 70 = ScrollLock (default). Use "help" for values

[egl]
# upscale  = none           # see overlay for FSR/CAS filters

[spice]
enable       = yes          # input/clipboard channel
clipboardSync = yes
```

Everything is also settable as long CLI flags (`app:shmFile=/dev/kvmfr0`, `win:fullScreen=yes`, …). Full option table: `looking-glass-client --help`. Handy extras for the ini:

```ini
[win]
autoResize = yes       # window follows guest resolution
autoScreensaver = yes  # let guest apps inhibit your screensaver
[input]
captureOnFocus = yes   # enter capture mode on focus
autoCapture = yes      # try to stay captured when needed
[spice]
captureOnStart = yes   # captured from launch
clipboardToVM = yes    # direction switches (also clipboardToLocal)
```

**Overlay mode** (`ScrLk+O`, exit with ESC) hosts the runtime config widget: Settings tab (performance-metrics graphs, EGL scale/night-vision) and **EGL filters tab** — post-processing applied top-to-bottom (order matters; experiment): *Downscaler* (undo bad guest upscaling), *AMD FSR* (spatial upscale with tunable sharpness), *AMD CAS* (contrast-adaptive sharpening). Save combinations as named **presets** (persisted under `~/.config/looking-glass/presets/`; the client won't auto-recall the last one — reselect each launch, or set `egl:preset=<name>`). Widget layout lives in `~/.config/looking-glass/imgui.ini` — don't hand-edit while the client runs.

**OBS plugin:** Looking Glass ships an OBS plugin that lets OBS *on the host* capture the VM with zero extra copies — `pkgs.looking-glass-client` includes it; in OBS choose the "Looking Glass" source.

## 8. Performance Tuning

The upstream "additional tuning" list, condensed (full rationale in base guide §5):

1. **Never give the guest all cores.** Reserve ≥2 cores (4 threads) for host: 6c/12t → guest 4c/8t max. 8c/16t → guest 6c/12t.
2. **Pin vCPUs** to host threads, SMT-siblings paired (`<vcpupin>`, base guide §5.2). Pin the emulator threads to the leftover cores (`<emulatorpin>`).
3. **NUMA:** pin vCPUs to the die/socket physically wired to the passed GPU's slot.
4. **PCIe width:** a physical x16 slot is not necessarily x16 electrically — check `lspci -vv | grep LnkSta` (negotiated width); chipset x4 slots cost GPU perf.
5. **host-passthrough CPU** + AMD `topoext` (base guide §5.1).
6. **DMABUF path:** AMD/Intel host GPU + KVMFR module (this guide's default) — the client logs `app:allowDMA=yes` and frames arrive by GPU DMA.
7. **Guest:** disable vsync/G-Sync in-games (let the client pace frames); disable fullscreen "exclusive" optimizations issues by using the client's borderless fullscreen.
8. **FPS graph:** `ScrLk + D`, then `ScrLk + O` for the full metrics widgets — read your actual frame timing before tuning blind.

## 9. One-Key "Instant Windows" Launch (Hotkey)

The setup you described: press a hotkey on the Linux desktop → the passthrough VM boots (or resumes) with the GPU attached → the Looking Glass window appears fullscreen, keyboard/mouse captured, native GPU performance. Press quit (`ScrLk+Q`) → VM shuts down cleanly.

All of it is one script on your PATH + a KDE custom shortcut. Assumes the **two-GPU** layout (host GPU stays alive while the guest GPU is passed). For a single-GPU host, do §10 first: its hook is registered with libvirt and fires automatically when this script starts/stops the VM — no changes needed here.

### 9.1 The launcher script

NixOS-managed, on your PATH. It starts everything in the right order and waits for the client to exit before shutting the VM down:

```nix
{ config, pkgs, lib, ... }: {
  environment.systemPackages =
    let
      # ---- Tunables -------------------------------------------------
      vmName = "win10";                 # virsh domain name
      waitVM = 30;                      # seconds to wait for VM start
      lgArgs = "-F";                    # fullscreen; add e.g. win:size=...

      # ---- Helpers ---------------------------------------------------
      # NOTE: in this ''...'' string, ${...} interpolates NIX values.
      # Shell variables would need ''${'' escaping — we avoid them
      # entirely by baking everything in at build time.
      virsh = "${pkgs.libvirt}/bin/virsh";
      lg = "${pkgs.looking-glass-client}/bin/looking-glass-client";

      lg-launch = pkgs.writeShellScriptBin "lg-launch" ''
        set -euo pipefail

        # ----------------------------------------------------------
        # 1. Start the VM (idempotent if already running).
        #    In single-GPU mode the libvirt hook from §10 fires
        #    automatically on this call — we do NOT call it manually.
        # ----------------------------------------------------------
        if ! ${virsh} domstate ${vmName} 2>/dev/null | grep -q running; then
          ${virsh} start ${vmName}

          # Wait for the domain to reach "running" state. The Looking
          # Glass client below retries on its own while Windows boots.
          for i in $(seq 1 ${toString waitVM}); do
            ${virsh} domstate ${vmName} 2>/dev/null | grep -q running && break
            sleep 1
          done
        fi

        # ----------------------------------------------------------
        # 2. Run the client fullscreen. It keeps retrying until the
        #    guest host-app connects. Blocks until the user quits
        #    (ScrLk+Q) — then we fall through to shutdown.
        # ----------------------------------------------------------
        ${lg} ${lgArgs}

        # ----------------------------------------------------------
        # 3. Graceful ACPI shutdown of the guest; force-destroy after
        #    60s if Windows ignores it.
        # ----------------------------------------------------------
        ${virsh} shutdown ${vmName} --mode acpi || true
        for i in $(seq 1 60); do
          ${virsh} domstate ${vmName} 2>/dev/null | grep -q running || break
          sleep 1
        done
        if ${virsh} domstate ${vmName} 2>/dev/null | grep -q running; then
          ${virsh} destroy ${vmName} || true
        fi
        # §10's release/end hook (if present) fires automatically here.
      '';
    in
    [ lg-launch ];
}
```

### 9.2 The hotkey (KDE Plasma)

System Settings → Shortcuts → Add New → Command or Script:

- **Command:** `lg-launch`
- **Trigger:** pick your key (e.g. `Meta+W`)

That's the whole loop: hotkey → `lg-launch` → VM boots → Looking Glass fullscreen → work/game → `ScrLk+Q` → client exits → script ACPI-shuts the VM → host back to normal.

Alternatives:

- A desktop file + krunner: `kwriteconfig5`… or simply pin a `.desktop` on the taskbar with the same command for a click-launch.
- Hyprland: `bind = SUPER, W, exec, lg-launch` in your hyprland.conf.
- A systemd **user** service instead of a script — lets you bind `systemctl --user start lg-vm` and get journald logs; the script above is simpler and works everywhere.

### 9.3 Making the VM start instantly (resume instead of boot)

The "very fast" part of the videos you saw is usually **managed save**: the VM is suspended-to-disk once, and every launch resumes it in ~2–5 seconds with Windows exactly as left:

```bash
# One-time: instead of shutdown, save the VM state:
sudo virsh managedsave win10
# (or set <on_poweroff>save</on_poweroff> in the XML for automatic)

# Then `virsh start` (as in lg-launch) resumes it rather than booting.
```

Update the script's shutdown phase to `virsh managedsave ${vmName}` instead of `shutdown` and each session becomes: hotkey → resume (seconds) → LG connects instantly (guest app already running) → quit → managedsave (seconds). This is the closest thing to "console sleep" a VM can have.

> Note: managed save + changing VM XML (adding devices) are incompatible — libvirt will refuse the resume if hardware changed since the save. Redefine/refresh the save after XML edits (`virsh save-image-define` or just boot fresh once).

## 10. Single-GPU Passthrough (Hooks)

For machines with **one GPU** (e.g. laptop dGPU, or a desktop where the same card must serve both systems): around VM start you must (1) tear the driver off the GPU on the host, (2) bind `vfio-pci`, then after VM stop (3) bind the host driver back and restart the display stack. Automate with the declarative `virtualisation.libvirtd.hooks.qemu` from the base guide §3.

> When the guest runs in this mode, your Linux desktop has **no GPU** — the Looking Glass window cannot render. Single-GPU passthrough is therefore used with either: a secondary host GPU/iGPU for the desktop, or a full "takeover" where you drop to a TTY/kill the session for the VM duration. The takeover variant is what "hotkey → whole machine becomes Windows" videos show.

### 10.1 The hook script (declarative)

```nix
{ config, pkgs, lib, ... }: {
  # The single-GPU start/stop logic, installed as a libvirt hook.
  # libvirt calls: <domain> <operation> <sub-operation> <extra>
  # We care about: prepare/begin (VM about to start) and release/end (VM gone).
  virtualisation.libvirtd.hooks.qemu = {
    "00-lg-single-gpu" = pkgs.writeShellScript "lg-single-gpu-hook" ''
      GUEST="$1"; OPERATION="$2"; SUBOP="$3"

      # Only act for the Looking Glass VM:
      [ "$GUEST" = "win10" ] || exit 0

      # ---- Hardware identity (EDIT for your machine) -------------
      GPU_VGA="0000:07:00.0"     # from: lspci | grep -i vga
      GPU_AUDIO="0000:07:00.1"   # from: lspci | grep -i audio (same card)
      DRM_ID="card0"             # from: ls /sys/class/drm/ (your primary)

      detach() {
        # Stop everything that holds the GPU
        /run/current-system/sw/bin/systemctl stop display-manager.service 2>/dev/null || true
        sleep 2

        # Unload host driver stack (NVIDIA example; amdgpu for AMD:
        #   modprobe -r amdgpu)
        ${pkgs.kmod}/bin/modprobe -r nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null || true

        # Unbind current driver + bind vfio-pci for BOTH functions
        for dev in "$GPU_VGA" "$GPU_AUDIO"; do
          driver=$(basename "$(readlink "/sys/bus/pci/devices/$dev/driver")" 2>/dev/null || true)
          if [ "$driver" != "vfio-pci" ]; then
            echo "$dev" > "/sys/bus/pci/devices/$dev/driver/unbind" 2>/dev/null || true
            echo "vfio-pci" > "/sys/bus/pci/devices/$dev/driver_override" 2>/dev/null || true
            echo "$dev" > /sys/bus/pci/drivers_probe
          fi
        done
      }

      attach() {
        # Give the GPU back to the host driver
        for dev in "$GPU_VGA" "$GPU_AUDIO"; do
          echo "" > "/sys/bus/pci/devices/$dev/driver_override" 2>/dev/null || true
          echo "$dev" > /sys/bus/pci/drivers_probe
        done
        ${pkgs.kmod}/bin/modprobe nvidia_drm nvidia_modeset nvidia_uvm nvidia 2>/dev/null || true

        # Restart the desktop
        /run/current-system/sw/bin/systemctl start display-manager.service
      }

      case "$OPERATION/$SUBOP" in
        prepare/begin|started/begin) detach ;;
        stopped/end|release/end)    attach ;;
      esac
      exit 0
    '';
  };
}
```

### 10.2 VFIO prerequisites (same as base guide §8)

Keep the `vfio-pci.ids=` / `softdep … pre: vfio-pci` config from `Virtualization-NixOS.md` §8 — with `softdep`, the host driver normally loads *after* vfio-pci has claimed the IDs, and the hook above handles the transitional moments. Some prefer **no** `vfio-pci.ids` for single-GPU (letting the host use the GPU normally, hook does the full unbind→override dance at launch). Both work; the `ids` route is more deterministic, the no-`ids` route maximizes host uptime between sessions.

### 10.3 The takeover flow (no second GPU at all)

With the hook above and no host GPU:

1. Hotkey `lg-launch` (§9) → hook stops the display manager, unloads NVIDIA, binds vfio-pci → VM starts with the only GPU.
2. There is no desktop to render the LG client on — so in this mode you run the **client from a TTY** (`sudo systemctl isolate multi-user.target` first, or before stopping DM) or you keep a tiny iGPU enabled just for the desktop (best option if your CPU has one — enable it in BIOS, plug your monitor into the motherboard, done).
3. Quit LG → `lg-launch` runs the release path → hook rebinds the GPU and restartes SDDM.

> Recommended reality check: on a desktop, an AMD APU/iGPU host (or any cheap second card) driving the Linux desktop + your big dGPU passed to Windows gives the same one-key experience *without* losing the Linux session mid-game. The pure single-GPU takeover is the fallback, not the goal.

## 11. Troubleshooting

Symptom → fix (from the official B7 troubleshooting + NixOS wiki):

- **Client launches, black window / "desktop doesn't appear"**
  - Guest GPU has no display or dummy plug connected (§2) — Windows disables the output.
  - Guest host-app service not running: reinstall §6 step 3 as Administrator.
  - IVSHMEM size mismatch (§3 vs §5.2 sizes) — client shows a popup with the required size; resize BOTH the kernel param and QEMU object.
  - Guest capture disabled by RDP: don't RDP into the machine while using LG — the desktop composition changes.

- **`/dev/kvmfr0` is a regular file, not char device** (`ls -l` doesn't start with `c`, size > 0): a VM started before the module loaded. `sudo rm /dev/kvmfr0 && sudo modprobe kvmfr`, fix `boot.initrd.kernelModules` (§4) so it never recurs.

- **QEMU can't open /dev/kvmfr0 (permission denied)**: udev rule not applied (§4.2 — check `udevadm info /dev/kvmfr0 | grep kvm`), or `cgroup_device_acl` missing the path (§4.3).

- **QEMU aborts: "slot 1 function 0 not available for pcie-root-port, in use by ivshmem-plain"**: you used the legacy `-device ivshmem-plain,…` string syntax on QEMU ≥6.2/libvirt ≥7.9. Use the JSON object syntax in §5.2.

- **Hook doesn't fire**: libvirt reads hooks **at daemon start** — `sudo systemctl restart libvirtd` after changing `hooks.qemu`. Check placement: `ls /var/lib/libvirt/hooks/qemu.d/`.

- **Hook runs but GPU won't rebind**: `driver_override` left set — the attach path clears it (`echo "" > …/driver_override`); also check `journalctl -u libvirtd` for the hook's stderr — non-zero exit + stderr text is logged by libvirt.

- **Stutter/microstutter**: §8 items 1–4 (CPU pinning, reserved cores, PCIe width). Verify with the client's FPS/metrics overlay (`ScrLk+D`, `ScrLk+O`) — "maxiseconds" spikes = host scheduling, not LG.

- **Clipboard not working (guest↔host)**: guest needs **spice-guest-tools** (SPICE VDAgent), NOT qemu-ga; and exactly one VDAgent installed — check installed programs for a standalone VDAgent and remove it (double-install breaks sync).

- **5-button mouse broken / mouse absolute-vs-relative weirdness**: you still have `<input type='tablet'/>` in the XML — remove it, keep §5.3's virtio mouse/keyboard.

- **NVIDIA host GPU: high CPU in the client**: expected on the copy path without DMABUF (§2). If it matters, an AMD/Intel iGPU for the host side enables DMA.

- **Audio missing**: `<audio id='1' type='spice'/>` element (newer libvirt separates `<sound>` from `<audio>`), plus the client's PipeWire session (don't run the client over SSH without a pulse/pipewire env).

- **Client shows the desktop but with a SPICE-feed corner indicator**: the guest host-app service crashed or never started, so the client fell back to the virtual SPICE display. Fix the guest side (§6), don't tune the client.

- **Scream audio over IVSHMEM conflicts with LG**: both fight over the same ivshmem device (extra latency by design). Use Scream's default network transfer with a virtio-net device instead. If you insist, point LG at the other device with `os:shmDevice` (§6).

- **NVIDIA host GPU + Wayland: client crashes on click-drag** (`wp_linux_drm_syncobj` errors, upstream #1151/#1153 — NVIDIA explicit-sync bug; NVK/mesa unaffected): launch with `__NV_DISABLE_EXPLICIT_SYNC=1 looking-glass-client`.

- **Mouse wrong/slidey on entering the window**: guest-side Windows pointer precision — Control Panel → Mouse → Pointer Options → uncheck *Enhance pointer precision* (or the MarkC registry fix; works on Win10/11 despite the name).

- **Screen stops updating after idle**: Windows turned the display off (Power Options in the guest) — not an LG bug. Set display sleep to Never.

- **NixOS rebuild loses `/var/lib/libvirt` custom bits?** No — that directory is persistent state, not managed by Nix. Only the hooks dir is symlink-managed by the module; everything else you've edited via virsh survives rebuilds.

## 12. Reference Index

- Looking Glass downloads (host installer): <https://looking-glass.io/downloads>
- LG B7 docs (requirements, install, usage, troubleshooting): <https://looking-glass.io/docs/B7/>
- IVSHMEM/KVMFR module page: <https://looking-glass.io/docs/B7/ivshmem_kvmfr/>
- NixOS Wiki Looking Glass: <https://wiki.nixos.org/wiki/Looking_Glass>
- libvirt hooks spec: <https://libvirt.org/hooks.html>
- nixpkgs module (hooks, cgroups): `nixos/modules/virtualisation/libvirtd.nix`
- KVMFR kernel module packaging: `pkgs/os-specific/linux/kvmfr`
- SPICE guest tools: <https://www.spice-space.org/download.html>
- virtio-win: <https://fedorapeople.org/groups/virt/virtio-win/>
- Base stack & VFIO: `Virtualization-NixOS.md`
