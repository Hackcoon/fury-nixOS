# Web apps on NixOS (YouTube example)

Three ways to turn sites into app-window launchers on your box
(Brave 151, Firefox, vicinae/DMS spotlight pick up `.desktop`
files automatically). Fastest first.

## Method 1 — hand-written launcher (no rebuild, 2 minutes)

Brave/Chromium can open any site as a borderless app window:

```sh
mkdir -p ~/.local/share/icons ~/.config/brave-webapps/youtube
# grab an icon (Papirus has youtube icons once your pending
# papirus-icon-theme rebuild lands; until then download one):
curl -L -o ~/.local/share/icons/youtube.png \
  https://www.youtube.com/s/desktop/435d8b1c/img/favicon_144x144.png
```

Then `~/.local/share/applications/youtube.desktop`:

```ini
[Desktop Entry]
Name=YouTube
Comment=YouTube web app
TryExec=brave
Exec=brave --app=https://www.youtube.com --user-data-dir=/home/fury/.config/brave-webapps/youtube --class=YouTube
Icon=/home/fury/.local/share/icons/youtube.png
Terminal=false
Type=Application
Categories=AudioVideo;Video;
StartupNotify=true
StartupWMClass=YouTube
```

Notes:
- `--user-data-dir` gives YouTube its own profile: separate logins,
  extensions, and cookies from your main Brave. One dir per app.
  Never reuse the same dir for two apps — first instance locks the
  profile and the second window inherits it (first-instance trap).
- `--class=` + `StartupWMClass=` keep the taskbar/dock icon grouped
  on the app instead of generic Brave. Verify the real class with
  `mmsg get focusing-client` while it's focused (Wayland has no xprop).
- Icon must be an absolute path (`Icon=/home/fury/.local/share/icons/youtube.png`
  as above). Alternative: `~/.local/share/icons/hicolor/48x48/apps/youtube.png`
  with `Icon=youtube`, then run `gtk-update-icon-cache`. Bare `Icon=youtube`
  with the PNG directly in `~/.local/share/icons/` will not resolve.
- If vicinae/DMS doesn't list it immediately, restart the frontend
  (`vicinae server --replace`, or restart DMS) — `update-desktop-database`
  does not refresh vicinae.

Duplicate the pattern per app (Gmail, Spotify, WhatsApp…): new
profile dir, new class, new icon.

## Method 2 — declarative in home-manager (survives reinstalls)

In `/etc/nixos/home.nix`:

```nix
xdg.desktopEntries.youtube = {
  name = "YouTube";
  exec = "brave --app=https://www.youtube.com --user-data-dir=/home/fury/.config/brave-webapps/youtube --class=YouTube";
  icon = "/home/fury/.local/share/icons/youtube.png";
  terminal = false;
  categories = [ "AudioVideo" "Video" ];
  settings.TryExec = "brave";
  settings.StartupNotify = "true";
  settings.StartupWMClass = "YouTube";
};
```

Needs whatever provides the icon (absolute path above, or Papirus after your
rebuild, or `~/.local/share/icons/hicolor/48x48/apps/youtube.png` + `Icon=youtube`
+ `gtk-update-icon-cache`). Apply with your
normal rebuild. (`%h` is not valid in `Exec=` — no XDG specifier, no shell
expansion — so the absolute `/home/fury/...` path is required. Same for Method 1.)

## Method 3 — system-level package (all users, pure Nix)

In `modules/packages/system-packages.nix`, using `makeDesktopItem`:

```nix
(papirus-icon-theme)
(pkgs.makeDesktopItem {
  name = "youtube";
  desktopName = "YouTube";
  exec = "brave --app=https://www.youtube.com --class=YouTube";
  icon = "youtube";
  terminal = false;
  categories = [ "AudioVideo" "Video" ];
})
```

> ⚠️ System-level item, all users: do NOT hardcode `--user-data-dir=/home/fury/...`
> here — a store package must not point at one user's home. Keep per-user
> `--user-data-dir` launchers in Method 1/2 only; the system item above stays
> user-path-free (add `TryExec=brave`, trailing `;` on `Categories`, and
> `StartupNotify` as needed).

Same rebuild flow. Prefer Method 2 unless other users need the app.

## Firefox route

Firefox proper PWAs need the `firefoxpwa` package (not installed
here): site connector + `pkgs.firefoxpwa`, then install from the
page. Brave `--app` above is the path of least resistance on this
machine.

NixOS wiring (both lines required — extension talks to the
connector over native messaging, and `.desktop` entries call
`firefoxpwa` from `PATH`):

```nix
programs.firefox.enable = true;
programs.firefox.nativeMessagingHosts.packages = [ pkgs.firefoxpwa ];
environment.systemPackages = [ pkgs.firefoxpwa ];
```

Then install the "PWAsForFirefox" extension from AMO, run
`firefoxpwa runtime install`, and install sites from the page.
Per-user fallback if system Firefox is Home Manager-managed and
the extension can't see the connector:
`~/.mozilla/native-messaging-hosts/firefoxpwa.json` symlinked to
the store manifest. Verify with the extension's connector status
page before filing bugs.

## Wayland flags per GPU vendor (`--ozone-platform-hint`)

Chromium ≥140 defaults to `--ozone-platform-hint=auto`, so
explicit `--ozone-platform=wayland` is mostly legacy — but pin it
in launchers when you want deterministic behavior:

```ini
Exec=brave --app=https://www.youtube.com --ozone-platform-hint=auto --user-data-dir=/home/fury/.config/brave-webapps/youtube --class=YouTube
```

- **AMD / Intel (Mesa, native Wayland):** no extra flags.
  `hint=auto` picks Wayland under Mango, XWayland fallback if
  needed. If a webapp lands on XWayland (blurry, no
  `mmsg` appid match), force `--ozone-platform=wayland`.
- **NVIDIA proprietary:** same `hint=auto` on driver ≥555
  (explicit-sync era). On older drivers (pre-555, no explicit
  sync) add `--enable-features=WaylandLinuxDrmSyncobj` — without
  it you get flicker/tearing or fallback to X11. Nouveau/NVK
  behaves like AMD/Intel (no syncobj flag needed).
- Applies identically to `--app` windows: they inherit whatever
  flags are on the `Exec=` line. Test per-app with
  `brave://version` (check "Command Line") inside the app window.

## Hardware video decode per vendor + verification

Webapp windows share Brave's GPU stack — flags go on the same
`Exec=` line, one profile dir keeps its own
`brave://gpu` state but not its own flag set.

- **AMD / Intel (VA-API, best-supported path):**
  ```ini
  Exec=brave --app=https://www.youtube.com --enable-features=VaapiVideoDecoder --user-data-dir=/home/fury/.config/brave-webapps/youtube --class=YouTube
  ```
  Needs `libva` + Mesa VA driver (`libva-vdpau-driver` not
  needed). Check host-side first: `vainfo` should list
  H264/HEVC/VP9/AV1 entries. No `LIBVA_DRIVER_NAME` override.
- **NVIDIA proprietary (NVDEC via VA-API shim):**
  needs `libva-nvidia-driver` (aka `nvidia-vaapi-driver`) plus:
  ```ini
  Exec=env LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct brave --app=https://www.youtube.com --enable-features=VaapiOnNvidiaGPUs,VaapiIgnoreDriverChecks,AcceleratedVideoDecodeLinuxGL,AcceleratedVideoDecodeLinuxZeroCopyGL --user-data-dir=/home/fury/.config/brave-webapps/youtube --class=YouTube
  ```
  AV1 on tagged releases ≤0.0.17 is broken (internal decoding
  error → silent dav1d fallback); VP9/H264 work, or build the
  driver from master. `--ignore-gpu-blocklist` sometimes needed
  after major Chromium bumps (147/148 regressed once already).
- **Verification (inside the app window, not main Brave):**
  1. `brave://gpu` → "Video Acceleration Information" lists
     Decode profiles (not "Software only").
  2. Play 4K60 VP9/AV1 fullscreen, then DevTools (Ctrl+Shift+I)
     → Media tab → decoder should read `VaapiVideoDecoder`,
     not `VpxVideoDecoder`/`dav1d`.
  3. Host-side: `nvidia-smi dmon` shows `dec` activity on
     NVIDIA; `intel_gpu_top` / `radeontop` on Intel/AMD.
     `chrome://gpu` can lie (advertises profiles while runtime
     decode fails) — trust the Media tab + `dec` counter.
  4. If decode falls back: re-check `brave://version` command
     line (first-instance trap steals flags from the main
     profile — kill all Brave or use a fresh `--user-data-dir`).

## Electron webapps?

Some "webapps" ship as Electron wrappers instead of `--app`
windows (see `apps-fixed.nix`). Rule of thumb: prefer Brave
`--app` (native Wayland, shared Brave updates, no per-app
Chromium bundle). Use Electron only when the site needs
tray/background/push that `--app` can't do. Electron honors the
same Ozone hint: `env=ELECTRON_OZONE_PLATFORM_HINT,auto` is
already in the Mango/DMS recommended env block — don't force
those wraps to X11 unless the specific app breaks on Wayland.

## Mango/DMS integration tips

- Window rules work on web apps via their class, e.g.:
  `windowrule=isfloating:1,appid:^YouTube$` (confirm `appid` with
  `mmsg get focusing-client`).
- Set per-app defaults in DMS: `dms ipc call defaultApp browser`
  (also musicPlayer/videoPlayer if a web app should own links).
- Your Electron wraps (`apps-fixed.nix`) force some apps to X11 —
  Brave web apps stay native Wayland; don't add them there.
- GPU video decode in Brave web apps follows your normal Brave
  flags; test with `brave://gpu` inside the app window.
