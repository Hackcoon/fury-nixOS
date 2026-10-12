# QUICKSHELL — The Everything Guide
### Building literally any panel, bar, widget, overlay, daemon, and desktop shell you can imagine

> **Quickshell** (quickshell.org, by outfoxxed & contributors, LGPL-3.0) is a **flexible QtQuick-based desktop shell toolkit**. It is *not* a bar — it's the *framework you build bars with* (and launchers, notifiers, islands, lock screens, OSDs, greeters, whole DE-shells). Written in **QML** (declarative UI + reactive JavaScript) with C++ services underneath: Wayland layershell, Hyprland/i3 IPC, PipeWire, MPRIS, notifications, UPower, NetworkManager, Bluetooth, System Tray (SNI), Polkit, PAM, greetd.
>
> Real things built with it: **Tide Island** (your dynamic island), **Noctalia**, **DankMaterialShell**, **Caelestia**, **qylock** (your SDDM/lockscreen theme), end-4's dots-hyprland UI, zephyr.
>
> **Sources for this guide:** official docs (quickshell.org v0.3.0 guide + type reference), the actual quickshell source tree (headers = ground truth for every property below), nixpkgs packaging, and the major community shells. Every API listed here was verified against the source. Version pinned: **v0.3.0/v0.3.1** (what's in your nixpkgs 26.05).

---

## Table of Contents

**PART I — FOUNDATIONS**
1. [Mental model: what Quickshell actually is](#1-mental-model)
2. [Install, run, and the config system](#2-install-run-config)
3. [QML crash course for shell-builders](#3-qml-crash-course)
4. [The Quickshell object model: Scope, ShellRoot, Singletons, Variants](#4-object-model)
5. [Windows: PanelWindow, FloatingWindow, PopupWindow](#5-windows)
6. [Sizing & positioning correctly (the #1 source of bugs)](#6-sizing)
7. [The Quickshell global object & path system](#7-quickshell-global)

**PART II — DATA & I/O**
8. [Process, StdioCollector, SplitParser — running things](#8-process)
9. [FileView + JsonAdapter — files & config that hot-reload](#9-fileview)
10. [Socket & SocketServer — raw IPC for any WM](#10-sockets)
11. [IpcHandler — your shell's own CLI](#11-ipchandler)
12. [SystemClock, Timer, ScriptModel, ElapsedTimer](#12-time-models)

**PART III — THE SERVICE LAYER (everything desktop)**
13. [Hyprland integration](#13-hyprland)
14. [Pipewire (audio) — nodes, volumes, peak meters, links](#14-pipewire)
15. [MPRIS — media players](#15-mpris)
16. [Notifications — build your own daemon](#16-notifications)
17. [System Tray (SNI) + DBusMenu](#17-tray)
18. [UPower + PowerProfiles](#18-upower)
19. [Networking (NM/iwd): WiFi scanning, wired, connectivity](#19-networking)
20. [Bluetooth](#20-bluetooth)
21. [Desktop entries (app launchers)](#21-desktopentries)
22. [Polkit agent, PAM, greetd — the auth stack](#22-auth)

**PART IV — WAYLAND DEEP-CUTS**
23. [WlrLayershell — layers, keyboard focus, namespaces](#23-layershell)
24. [Toplevels (foreign-toplevel): taskbars & alt-tabs that work everywhere](#24-toplevels)
25. [Session locks (WlSessionLock) — build a lockscreen](#25-lockscreen)
26. [Idle: IdleMonitor + IdleInhibitor](#26-idle)
27. [BackgroundEffect — compositor blur from your shell](#27-backgroundeffect)
28. [Screencopy, ShortcutInhibitor, i3](#28-misc-wayland)

**PART V — WIDGET CRAFT**
29. [Widgets toolkit: IconImage, wrappers, ClippingRectangle, QsMenu](#29-widgets)
30. [QtQuick Controls + styling your shell](#30-controls)
31. [Effects: shadows, multi-effect, animations, easing](#31-effects)
32. [ColorQuantizer — wallpaper-based theming built-in](#32-colorquantizer)

**PART VI — PRAGMAS, PACKAGING, NIXOS**
33. [Pragmas & environment — tuning the engine](#33-pragmas)
34. [Packaging shells for NixOS (with real examples)](#34-nix-packaging)

**PART VII — THE BIG RECIPE BOOK**
35. [Recipe: a complete bar from scratch](#35-recipe-bar)
36. [Recipe: app launcher](#36-recipe-launcher)
37. [Recipe: notification center + toasts](#37-recipe-notifications)
38. [Recipe: OSD popups (volume/brightness)](#38-recipe-osd)
39. [Recipe: power/exit menu](#39-recipe-powermenu)
40. [Recipe: right-click desktop menu, cliphist picker, calendar, cava, lockscreen, greeter](#40-more-recipes)
41. [Architecture patterns: singletons everywhere, LazyLoader, memory, reloads](#41-patterns)
42. [Debugging, LSP, and workflow](#42-debugging)

---

# PART I — FOUNDATIONS

## 1. Mental model

```
┌────────────────────────────────────────────────────────────┐
│ quickshell (the binary)                                    │
│  ├─ QML engine (QtQuick scene graph — GPU rendered)        │
│  │    └─ YOUR shell.qml + every .qml file it references    │
│  ├─ Wayland client (layershell, toplevels, session locks…) │
│  ├─ Services (C++ singletons exposed to QML):              │
│  │    Hyprland, Pipewire, Mpris, Notifications, SystemTray,│
│  │    UPower, Networking, Bluetooth, DesktopEntries,       │
│  │    Polkit, Pam, Greetd, I3                               │
│  ├─ IO: Process, Socket, FileView, IPC server             │
│  └─ Hot reload: file watcher → instant config reload        │
└────────────────────────────────────────────────────────────┘
```

Five ideas and you understand Quickshell:

1. **Everything is a QML object tree.** Your shell is a tree of `PanelWindow`s, `Item`s, `Text`s, and service singletons.
2. **Bindings are reactive.** `text: clock.hours + ":" + clock.minutes` re-renders automatically when the clock ticks. You almost never "push" data — you bind to it.
3. **Services are singletons** with observable properties: bind `Pipewire.defaultAudioSink.audio.volume` and your slider is *live* — no polling, no scripts.
4. **Windows are surfaces**: `PanelWindow` = layershell surface (bars/overlays — what 90% of shell work is), `FloatingWindow` = normal window, `PopupWindow` = attached to a parent.
5. **Hot reload is sacred.** Save file → entire config reloads in ~100ms. The dev loop is: keep `quickshell -p .` running, save, look, repeat.

**Compared to alternatives:** Waybar (JSON/CSS, limited), AGS/Astal (GTK+JS, heavier), EWW (Yuck-lisp, no services layer). Quickshell's niche: a *real* UI toolkit (QtQuick) + a *real* desktop-services layer + live reload + one process for everything (FAQ: "Should I use a process per widget? **No.**").

---

## 2. Install, run, config

### Install

- NixOS: `quickshell` in nixpkgs (0.3.0) — or the flake `github:quickshell-mirror/quickshell` for git builds.
- Arch: AUR `quickshell-git`. Fedora via Terra. Gentoo via GURU.
- Source: CMake (needs Qt ≥ 6.6 base/declarative/wayland/svg, cli11, wayland, wayland-protocols, libdrm, libgbm, pipewire, pam, jemalloc, spirv-tools...).

### The config system

Quickshell searches the `quickshell` subfolder of **every XDG config path** (normally `~/.config/quickshell/`). Rules (from the intro guide):

- Every **named subfolder containing `shell.qml`** is a config.
- If the base `quickshell/` folder itself has a `shell.qml`, subfolders are ignored.
- Pick a config with `--config NAME` / `-c NAME`.
- Run **any** path (outside XDG, even a bare `.qml` file) with `--path PATH` / `-p PATH`.

```bash
quickshell                       # default config
quickshell -c myshell           # ~/.config/quickshell/myshell/shell.qml
quickshell -p ~/dev/myshell     # dev directly from a git checkout
quickshell -p ~/dev/myshell/shell.qml   # even a single file
```

> ⚠ **Never use `import "root:/path"` (root imports).** Old feature; breaks the LSP and singletons. Use `import qs.xxx` (§3).
> ⚠ Keep `QS_DISABLE_FILE_WATCHER=1` in mind if you ever *don't* want reloads (CI/tests).

### Running during development

```bash
quickshell -p ~/dev/myshell    # terminal stays attached: you see WARN/ERROR lines live
# save any .qml file → instant reload; errors appear in the same terminal
```

Multiple instances of *different* configs can coexist (each gets its own IPC socket); the same config twice is detected as a duplicate.

---

## 3. QML crash course

QML = declarative object trees + reactive JS expressions. This is the *entire* language you need; details below are from the official QML Language page.

### The shape of a document

```qml
// shell.qml — every QML file starts with imports
import QtQuick          // module import (version optional in Qt6)
import Quickshell
import Quickshell.Io
import QtQuick.Layouts 6.0 as L      // namespaced
import "helpers.js" as Js           // javascript file
import qs.services                   // ⭐ Quickshell-style import: path relative to shell.qml's folder
import qs.widgets as W               // qs = shell root; dotted paths qs.foo.bar

// Root object — the file *is* this type
Scope {
  id: root                    // ids are file-scoped names, lowercase
  property string time: ""    // property definition (reactive storage)

  // property BINDING: an expression; re-evaluated when dependencies change
  readonly property int hourCount: time.length

  signal somethingHappened(x: int)          // custom signal
  function double(x: int): int { return x * 2 }   // function
  component Pill: Rectangle { radius: 99 }  // inline component (file-scoped type)

  // signal handler: on<Signal> capitalized
  onSomethingHappened: x => console.log("got", x)

  Text { text: root.time }     // object assigned to the default property
}
```

### Properties & bindings — the core skill

```qml
Item {
  property int simple: 5
  property int expr: 5 * 20 + otherProp         // last line of a block = return value
  property var complex: {
    const a = computeA();
    const b = computeB();
    a * b + simple                             // implicit return
  }

  // definition modifiers: [required] [readonly] [default] property <type> <name>
  required property string label               // consumers MUST set it (enforced!)
  readonly property bool ready: loader.status === Loader.Ready
  default property var payload                 // this property receives un-assignmented children
}
```

**Reactivity**: every binding tracks the properties it reads. Change a dependency → every dependent binding re-evaluates, *through function calls too*:

```qml
ColumnLayout {
  property int clicks: 0
  function label(): string { return `clicked ${clicks}×` }  // reactivity flows through
  Button { onClicked: clicks += 1 }
  Text { text: label() }   // re-renders on every click
}
```

### Scoping rules (memorize these — the #1 confusion)

A property is usable *unqualified* if it's defined:
1. on the **current object**,
2. on the **root object of the current file**.

Anything else → access by `id` (or `parent`, carefully — `parent` is visual parent, not necessarily the enclosing object):

```qml
Item {                    // root
  property string rootDef
  Item {
    id: mid
    property string midDef
    Text {
      text: rootDef          // ✅ root scope
      text: this.midDef      // ❌ not on this object or root
      text: mid.midDef       // ✅ via id
    }
  }
}
```

**IDs are file-scoped.** An id inside a component (e.g. inside a Variants delegate) cannot be referenced from outside it — that's why you hoist state to root properties or singletons (§4).

### Signals, handlers, Connections

- Every signal `foo` gets an implicit `onFoo` handler.
- Every property `bar` has a change signal `barChanged` / handler `onBarChanged`.
- To listen to something **outside your file** (e.g. a singleton!) use `Connections`:

```qml
// The canonical way to react to a Quickshell service:
Connections {
  target: Hyprland                      // singleton, from Quickshell.Hyprland
  function onFocusedWorkspaceChanged() { ... }   // indirect handler syntax
  function onRawEvent(event) { ... }
}
```

### Lambdas / functions as values

```qml
property var operation: number => number * 2
someApi.registerCallback(result => label.text = result)
```

### Creating your own types

**Every uppercase-named `.qml` file is a type** implicitly importable from neighbors. Conventions:

```
~/.config/quickshell/myshell/
├── shell.qml                 ← entry
├── Bar.qml                   ← type, usable as Bar { } anywhere in the config
├── services/
│   ├── Theme.qml             ← pragma Singleton → global theming
│   └── Time.qml
├── widgets/
│   ├── ClickableRect.qml
│   └── Pill.qml
└── modules/
    └── PowerMenu.qml
```

```qml
// widgets/ClickableRect.qml — a reusable, API-clean type
import QtQuick

Rectangle {
  id: root
  required property string label          // consumer must provide
  signal clicked(eventPoint: point)        // my own event
  signal rightClicked(eventPoint: point)
  property color normalColor: "#1c1c1e"
  property color hoverColor: "#343437"

  color: mouseArea.containsMouse ? hoverColor : normalColor

  Text { anchors.centerIn: parent; text: root.label; color: "white" }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    onClicked: e => root.clicked(e.position)
    acceptedButtons: Qt.LeftButton | Qt.RightButton
  }
}
```

### Singletons (pragma Singleton)

```qml
// services/Theme.qml — ONE instance for the whole shell
pragma Singleton
import QtQuick
import qs.config

QtObject {                       // non-visual root!
  readonly property color bg:     "#1a1b26"
  readonly property color accent: "#7aa2f7"
  readonly property int   radius: 12
}
```

Usage — no import needed for same-folder files; for subfolders `import qs.services` then `Theme.bg`. Rules from the docs: put `pragma Singleton` at top **and** make a *non-visual* root (`QtObject` or `Singleton`) — singletons of visual types cause weird lifetime bugs.

---

## 4. Object model

### Scope / ShellRoot

`Scope` is the non-visual container for a shell's logic (windows, processes, state) — the modern root type. `ShellRoot` is the legacy name (still works: it's the base). Both give you the default-property behavior where children live without a parent Item.

```qml
import Quickshell
import QtQuick

Scope {
  id: root
  property var state: ({})     // shared shell state

  PanelWindow { ... }          // windows are children of Scope, not of an Item
  Process { ... }              // so are processes, sockets, singletons' Connections...
}
```

### Variants — "one per monitor" and friends

`Variants` instantiates a component per element of a model, injecting each into a `modelData` property. THE pattern for multi-monitor bars:

```qml
Variants {
  model: Quickshell.screens           // ← live-updating list; hotplug = bar appears/disappears

  PanelWindow {                        // implicit delegate (Variants' default property)
    required property var modelData    // each instance receives its screen
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: 34
    // ... bar content
  }
}
```

Notes from the docs:
- `Variants` is for **non-widget** items (windows, objects). For repeated *visual* items inside a window, use `Repeater` (or ListView).
- The delegate is a `Component` — meaning ids inside it **don't exist outside**, and zero-or-many instances is normal. Hoist shared state (next section).
- You can use any list as the model: `model: ["top", "bottom"]`, `model: Hyprland.monitors`, etc.

### The canonical state-hoisting pattern (from the official intro)

Problem: per-window copies of Process/Timer waste resources; ids inside delegates can't be referenced outside. Solution — root properties + shared non-visual objects:

```qml
Scope {
  id: root
  property string time: ""                    // THE shared state

  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData
      screen: modelData
      anchors { top: true; left: true; right: true }
      implicitHeight: 30
      Text { anchors.centerIn: parent; text: root.time }   // every bar reads same property
    }
  }

  Process {                                   // ONE process, not one per monitor
    id: dateProc
    command: ["date"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.time = this.text }
  }
  Timer {
    interval: 1000; running: true; repeat: true
    onTriggered: dateProc.running = true      // re-run by re-setting running
  }
}
```

Better still (replaces the Process+Timer entirely — §12): a `SystemClock` singleton-driven singleton service.

---

## 5. Windows

All windows share base properties (from `proxywindow.hpp` — the `QsWindow` interface): `visible`, `width`, `height`, `implicitWidth/Height`, `screen`, `color`, `devicePixelRatio`, `mask` (PendingRegion — click-through shapes!), `contentItem`, `surfaceFormat`, `updatesEnabled`, plus functions `itemPosition()`, `itemRect()`, `mapFromItem()`.

### PanelWindow — the layershell workhorse

`PanelWindow` is a wlroots **layer-shell** surface: it's how bars, docks, islands, OSDs, launchers exist outside normal window management. Full property surface (verified from panelinterface.hpp + wlr_layershell.hpp):

```qml
PanelWindow {
  // ── core (QsWindow) ──
  visible: true
  screen: Quickshell.screens[0]
  color: "transparent"            // window background; transparent → compositor blur-able
  // mask: <PendingRegion>         // click-through / input shape (§29 Region)

  // ── anchoring (which screen edges to stick to) ──
  anchors {
    top: true; bottom: false; left: true; right: true
  }
  margins {
    top: 0; bottom: 0; left: 0; right: 0
  }

  // ── space reservation (how tiled apps avoid you) ──
  exclusiveZone: 34               // px reserved (with exclusionMode Normal/Auto)
  exclusionMode: ExclusionMode.Ignore   // .Ignore | .Normal | .Auto — Ignore = overlay, no reserve

  // ── stacking & focus ──
  aboveWindows: true              // Top layer vs Bottom
  focusable: true                 // can take keyboard focus

  // ── raw layershell (from WlrLayershell attached type) ──
  WlrLayershell.layer: WlrLayer.Top          // Background|Bottom|Top|Overlay
  WlrLayershell.namespace: "my-bar"          // compositor layer-rules target this! (blur etc.)
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None   // None|OnDemand|Exclusive

  implicitHeight: 34               // for top/bottom bars; use implicitWidth for side docks
}
```

**Anchoring semantics** (official size/position semantics): anchoring to an edge attaches & sizes to that edge; anchoring only left+right + `implicitHeight` = full-width bar; anchoring *no* edges = a floating panel you position with `x`/`y` and size yourself (that's how islands and OSDs work). `exclusiveZone` interacts with anchors: zones are per-anchored-side. `ExclusionMode.Ignore` = never reserve (pure overlay — notifications, OSD); `Normal` = use exclusiveZone; `Auto` = reserve based on anchors+margins.

**The four usage archetypes:**

```qml
// 1) TOP BAR (reserves space)
PanelWindow {
  anchors { top: true; left: true; right: true }
  exclusiveZone: 34
  implicitHeight: 34
}

// 2) FLOATING ISLAND (centered pill, no reservation)
PanelWindow {
  anchors { top: true }                    // one anchor = positioned relative to it
  exclusionMode: ExclusionMode.Ignore     // overlay, no reserve (setting exclusiveZone forces Normal)
  implicitHeight: 40
  width: 200
  // center horizontally:
  x: screen?.width ? (screen.width - width) / 2 : 0   // relative positioning via x/y
}

// 3) FULL-SCREEN OVERLAY (launcher/lock) — covers everything, takes keyboard
PanelWindow {
  anchors { top: true; bottom: true; left: true; right: true }
  color: "#e6000000"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "launcher"
}

// 4) SIDE DOCK (vertical)
PanelWindow {
  anchors { left: true; top: true; bottom: true }
  implicitWidth: 64
}
```

### FloatingWindow — a normal window

For helper windows of your shell (settings app, calendar editor):

```qml
FloatingWindow {
  color: contentItem.palette.window
  minimumSize.width: 400        // from the official manual test example
  minimumSize.height: 300
  // behaves like a normal client: compositor tiles/floats it
}
```

### PopupWindow — attached popups (tooltips, context menus)

A window anchored **relative to a parent window/item**, following it:

```qml
PopupWindow {
  id: trayMenu
  anchor.window: bar             // parent QsWindow
  anchor.item: trayIcon          // or anchor to an item within a window
  anchor.edges: Edges.Bottom      // which side of the anchor
  anchor.gravity: Edges.Bottom    // which way the popup grows
  relativeX: 0                    // offset from anchor point
  relativeY: 4
  anchor.adjustment: PopupAdjustment.Flip      // slide/flip/resize when off-screen
  visible: false
  grabFocus: true                 // dismiss on outside-click (focus loss)
}
```

`PopupAnchor` props (from popupwindow.hpp + popupanchor.hpp): `window`, `item`, `edges`, `gravity`, `adjustment` (Flip/Slide/Resize), `backwardsNavigation`. The built-in `QsMenu`/`DBusMenu` types (§17, §29) drive popups for you.

---

## 6. Sizing

Straight from the official "Item Size and Position" page — internalize this or your widgets will be invisible:

- Every Item has **actual** size (`width`,`height`) and **implicit/desired** size (`implicitWidth`,`implicitHeight`).
- **Implicit flows UP (child → parent); actual flows DOWN (parent → child).**
- A container computes its implicit size from children's; it sets children's actual size from its own.
- An item managed by a container **never sets its own width/height** — only implicit.
- ⚠ Many QtQuick items default to **zero size** — the classic "invisible widget" bug. Quickshell logs a warning on visible windows with zero-sized children, but not always.

```qml
// CORRECT container pattern:
Item {
  property real margin: 5
  implicitWidth: child.implicitWidth + margin * 2
  implicitHeight: child.implicitHeight + margin * 2

  Rectangle {
    id: child
    anchors.fill: parent
    anchors.margins: parent.margin
    implicitWidth: 50; implicitHeight: 50   // desired size; parent respects unless stretched
  }
}
```

- **`childrenRect` is a trap** — it reads children's *actual* geometry → binding loop. Never size a container from `childrenRect`.
- **Use `RowLayout`/`ColumnLayout`/`GridLayout` (not `Row`/`Column`)** — Layouts pixel-align, support the `Layout.` attached props (`Layout.preferredWidth`, `Layout.fillWidth`, `Layout.alignment`, `Layout.minimumWidth`...), default spacing is 5px.
- **MarginWrapperManager / WrapperItem / WrapperRectangle / WrapperMouseArea** (§29): built-ins that wrap a single child with margins and handle all this for you.
- **Zero-size item invisible?** — check implicit sizes of children, check that content isn't in a zero-implicit-height Item.
- **Rounded window** (FAQ): transparent window + rounded Rectangle inside; remember `border.width: 0` if you touch `border` at all (QTBUG-137166 hole-in-window workaround!).
- **Window transparency**: if a window may switch opaque↔transparent, set `surfaceFormat.opaque: false` (Quickshell optimizes opaque windows into opaque surfaces).

---

## 7. Quickshell global

The `Quickshell` singleton (verified https://quickshell.org/docs/v0.3.0/types/Quickshell/Quickshell/):

```qml
// ── identity & paths ──
Quickshell.processId            // this process
Quickshell.workingDirectory     // cwd (settable)
Quickshell.watchFiles           // hot reload on/off
Quickshell.clipboardText        // read/write the clipboard! (string property)
Quickshell.screens              // ⭐ live list of ShellScreen (name, width, height...)
Quickshell.shellDir             // root dir of the shell (folder containing shell.qml)
Quickshell.shellRoot            // DEPRECATED alias of shellDir
Quickshell.configDir            // DEPRECATED alias of shellDir
Quickshell.cacheDir / Quickshell.cachePath(p)    // XDG cache (per-shell)
Quickshell.dataDir  / Quickshell.dataPath(p)     // XDG data (per-shell)
Quickshell.stateDir / Quickshell.statePath(p)    // XDG state (per-shell)
Quickshell.shellPath(p)         // == ${shellDir}/${p}; configPath(p) is its deprecated alias
// NOTE: AppId/ShellId are pragmas (//@ pragma AppId / //@ pragma ShellId), NOT Quickshell properties.
// No instanceId/shellId/appId/launchTime properties. No runtimePath() — use dataPath/statePath or /tmp for sockets.

// ── functionality ──
Quickshell.env("NAME")          // read env var
Quickshell.reload(hard: bool)   // programmatic reload
Quickshell.execDetached(["cmd", "arg"])   // fire-and-forget spawn (no Process object)
Quickshell.iconPath("edit-copy")             // icon theme lookup — ⚠ missing-texture box if missing
Quickshell.iconPath("edit-copy", true)       // check=true → empty string if missing (no fallback box)
Quickshell.iconPath("edit-copy", "edit-paste") // explicit fallback icon
Quickshell.hasThemeIcon("name")
Quickshell.hasVersion(0, 3)      // feature-gate your config across versions!
Quickshell.hasQtVersion(6, 8)
Quickshell.inhibitReloadPopup() // you replaced the crash/reload popup with your own
```

Path conventions (FAQ): relative string paths in `Image`/`FileView` resolve to the **working directory** — use `Qt.resolvedUrl("file.png")` for file-relative, and `Quickshell.cachePath("thumbs/x.png")` for cache-scoped.

---

# PART II — DATA & I/O

## 8. Process

`Process` (Quickshell.Io) — run commands, async, streamable. Full surface from process.hpp:

```qml
Process {
  id: proc
  command: ["bash", "-c", "echo hi | jq ."]    // ⚠ argv list — no implicit shell; use bash -c for pipes
  running: true                 // set true → (re)start; set false → kill
  workingDirectory: "/tmp"
  environment: ({ QT_QPA_PLATFORM: "wayland" })   // merged env
  clearEnvironment: false        // true = run with ONLY `environment`
  stdinEnabled: true             // allow write()

  stdout: StdioCollector {               // option A: collect whole output
    onStreamFinished: label.text = this.text
  }
  // stdout: SplitParser {              // option B: line-by-line streaming
  //   onRead: data => lines.append(data)
  //   splitMarker: "\n"                // default; can be any string
  //   waitForEnd: false
  // }

  // stderr: SplitParser { onRead: warn(data) }

  onStarted:  console.log("pid", processId)
  onExited: (code, status) => console.log("exit", code, status)

  function ask(input) { write(input + "\n") }    // stdin
}
```

Functions: `exec(cmdList)` (one-shot convenience), `exec(ctx)` with a context object, `signal(sig)` (send POSIX signal — `proc.signal(9)`), `write(str)` (stdin), `startDetached()`.

**Rules of thumb (FAQ):** short output → StdioCollector; long-running streamers (cava, `hyprctl` events, `journalctl -f`) → SplitParser; whole-script with pipes → `bash -c`. One process per widget = memory bloat — hoist via singletons (§41).

## 9. FileView + JsonAdapter

`FileView` reads/writes files **asynchronously** with change watching. `JsonAdapter` makes JSON files into live QML objects. THE pattern for shell configuration files:

```qml
// services/Config.qml (singleton)
pragma Singleton
import QtQuick
import Quickshell.Io

Singleton {
  id: root
  // FileView with a JsonAdapter:
  FileView {
    path: Quickshell.statePath("settings.json")
    watchChanges: true                    // reload when the file changes on disk (hot reload from other tools!)
    printErrors: true

    JsonAdapter {
      property string wallpaper: ""       // ← your JSON keys as properties
      property bool darkMode: true
      property real scale: 1.0
      property var workspaces: []         // nested arrays/objects map to var
      onObjectChanged: console.log("config saved/loaded")
    }

    onFileChanged: reload()               // re-read + re-parse on external change
  }

  // typed, reactive accessors for the rest of the shell:
  readonly property alias wallpaper: /* adapter.wallpaper via alias */
}
```

FileView details (fileview.hpp): `path`, `preload` (load at startup), `blockLoading`, `blockAllReads`, `printErrors`, `watchChanges`, `blockWrites`, `atomicWrites` (write via tmp+rename — set true!), `adapter`; functions `text()`/`data()` (pull current content), `setText()`/`setData()` (write), `reload()`, `writeAdapter()` (persist adapter state), `waitForJob()`. JsonAdapter maps nested JSON paths to dotted properties automatically.

This means: **your shell's settings file is reactive state** — the settings GUI you build writes adapter properties → `writeAdapter()` → file; external edits hot-apply. (Tide Island's whole `userconfig.json` works exactly this way in C++.)

## 10. Sockets

`Socket` / `SocketServer` (Quickshell.Io) — for WMs without first-class support (FAQ: "Work with an unsupported WM"):

```qml
Socket {
  path: "/tmp/mywm.sock"       // unix socket
  connected: true              // connect when true
  onConnectedChanged: console.log(connected ? "up" : "down")
  function send(data) { write(data); flush() }
  handler: SplitParser { onRead: line => handleIpc(line) }   // incoming stream
}

SocketServer {
  path: Quickshell.dataPath("my.sock")   // serve! (no runtimePath() — use dataPath/statePath or /tmp)
  active: true
  handler: Component {        // per-connection handler component
    Socket {
      onRead: ...             // hmm — see SplitParser/DataStream composition
    }
  }
}
```

(Composition pattern: `Socket` + `SplitParser`/`DataStream` parsers — same streaming system as Process.) This is how you'd talk to sway's IPC, river, dwl, custom daemons — anything with a unix socket.

## 11. IpcHandler

`IpcHandler` (Quickshell.Io) exposes **functions as CLI commands** over quickshell's per-instance IPC socket. This is how Hyprland/your WM/scripts/other programs control your shell:

```qml
// In any file (commonly shell.qml or an ipc/ module):
IpcHandler {
  target: "bar"                       // command namespace: quickshell ipc <target> <function>

  function show(): void { bar.visible = true }        // becomes `quickshell ipc bar show`
  function hide(): void { bar.visible = false }
  function toggle(): void { bar.visible = !bar.visible }
  function setColor(color: string): void { theme.bg = color }
  function notify(text: string, timeout: int): void { toast.show(text, timeout) }  // typed args!
  enabled: true
}
```

Calling from anywhere:

```bash
quickshell ipc bar show
quickshell ipc bar setColor "#ff0000"
quickshell ipc --list                 # discover targets/functions
# another instance? select it:
quickshell --p /path/to/shell ipc ...  # or by instance id
```

Bindings in Hyprland (`hyprland.lua` — see companion guide):

```lua
hl.bind("SUPER + B", hl.dsp.exec_cmd("quickshell ipc bar toggle"))
```

FAQ: "Open/close windows with commands" → exactly this: IPC functions flip `window.visible` or a `LazyLoader.active`. Tide Island's whole `island show` / `overview toggle` / `tide togglePlayer` surface (its three IpcHandlers) is this type — you now know it cold.

## 12. Time & models

### SystemClock — the clock without processes

```qml
SystemClock {
  id: clock
  precision: SystemClock.Seconds    // Minutes | Hours | Seconds — re-render granularity
  enabled: true
  // → live: date (QDateTime), hours, minutes, seconds
}
Text { text: `${clock.hours}:${clock.minutes}` }
```

Replace the intro's Process+Timer with this (one object, no re-spawns).

### Timer (QtQuick) — schedule QML-side

```qml
Timer { interval: 500; running: cond; repeat: true; onTriggered: doThing() }
```

### ScriptModel — JS arrays as ListModels

```qml
ScriptModel {
  values: [{name:"a"},{name:"b"}]     // plain JS array (can be a reactive binding!)
  objectProp: "entry"                   // expose each element under this role name
  comparisonMode: ScriptModel.Flexible // strictness of change detection
}
ListView { model: scriptModel; delegate: Text { required property var entry; text: entry.name } }
```

### ElapsedTimer / EasingCurve

`ElapsedTimer` — measure time in QML. `EasingCurve` — named easing for animations (wraps QEasingCurve): pair with `Behavior`/`NumberAnimation` for the rice (§31).

---

# PART III — THE SERVICE LAYER

## 13. Hyprland

`import Quickshell.Hyprland` — the `Hyprland` singleton (verified from qml.hpp + monitor.hpp + workspace.hpp + hyprland_toplevel.hpp):

```qml
Hyprland.usingLua            // bool — is the compositor on Lua-era config (≥0.55)! Gate your dispatches
Hyprland.requestSocketPath   // request socket
Hyprland.eventSocketPath     // event socket
Hyprland.focusedMonitor      // HyprlandMonitor
Hyprland.focusedWorkspace    // HyprlandWorkspace
Hyprland.activeToplevel      // HyprlandToplevel
Hyprland.monitors            // live ObjectModel
Hyprland.workspaces          // live ObjectModel (all)
Hyprland.toplevels           // live ObjectModel (all windows)
Hyprland.dispatch("hl.dsp.focus({ workspace = \"e+1\" })")   // ⭐ dispatch anything
Hyprland.monitorFor(screen)  // map a Quickshell screen → Hyprland monitor
Hyprland.refreshMonitors()   // manual refresh (auto normally)
Hyprland.refreshWorkspaces()
Hyprland.refreshToplevels()
```

Object shapes:

```qml
// HyprlandMonitor: id, name, description, x, y, width, height, scale, activeWorkspace, focused
// HyprlandWorkspace: id, name, active, focused, urgent, hasFullscreen, monitor, toplevels
// HyprlandToplevel: address, title, activated, urgent, workspace, monitor, lastIpcObject (raw!)
```

**Dispatching across the 0.55 boundary** — `Hyprland.usingLua` tells you which grammar: Lua-era `hl.dsp.window.close({ window = "..." })` vs classic `hyprctl`-style strings. Tide Island's HyprlandDispatch.qml builds `hl.dsp...` strings; if you're on classic Hyprland, send classic strings. Feature-gate:

```qml
Component {
  Hyprland.focusWorkspace: i => Hyprland.dispatch(
    Hyprland.usingLua ? `hl.dsp.focus({ workspace = "e+${i}" })` : `workspace e+${i}`
  )
}
```

Events (official test example reads models; you can also hook raw events):

```qml
Connections {
  target: Hyprland
  function onFocusedWorkspaceChanged() { flash.start() }
  function onFocusedMonitorChanged() { ... }
}
```

Live workspace bar — the official manual test, adapted:

```qml
Row {
  Repeater {
    model: Hyprland.workspaces
    delegate: Rectangle {
      required property var modelData           // HyprlandWorkspace
      radius: 6
      implicitSize: 30
      color: modelData.focused ? accent : modelData.urgent ? red : surface
      Text { anchors.centerIn: parent; text: modelData.id }
      MouseArea { onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = "${modelData.id}" })`) }
    }
  }
}
```

Also available: `HyprlandFocusGrab` (region-based focus capture for launcher dismiss behavior!), `GlobalShortcut` (register D-Bus/global shortcuts, see GlobalShortcut type), `HyprlandEvent` (raw event parsing).

## 14. Pipewire

`import Quickshell.Services.Pipewire` — the `Pipewire` singleton + object types (verified from qml.hpp):

```qml
Pipewire.defaultAudioSink        // PwNode — your output
Pipewire.defaultAudioSource      // PwNode — your mic
Pipewire.preferredDefaultAudioSink = node    // set persisted default (WRITE — survives!)
Pipewire.preferredDefaultAudioSource = node
Pipewire.nodes                   // ALL nodes (sinks, sources, streams) — ObjectModel
Pipewire.links / Pipewire.linkGroups
Pipewire.ready                   // bool

// PwNode:
node.id / node.name / node.description / node.nickname / node.properties (variant map!)
node.isSink / node.isStream / node.type
node.audio                       // PwNodeAudio | null (only audio nodes)

// PwNodeAudio — the money object:
audio.muted                      // bool, WRITE
audio.volume                     // AVERAGE volume, WRITE (0..1)
audio.volumes                    // per-channel array, WRITE
audio.channels                   // [PwAudioChannel.FL, ...]

// PwObjectTracker — bind object lifetime (place in your root):
PwObjectTracker { objects: [ Pipewire.defaultAudioSink?.audio ] }
```

**The canonical volume widget** — zero polling, zero pactl, zero scripts:

```qml
// services/Audio.qml (singleton)
pragma Singleton
import QtQuick
import Quickshell.Services.Pipewire

Singleton {
  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property bool muted: sink?.audio?.muted ?? false
  readonly property real volume: sink?.audio?.volume ?? 0
  function toggle() { if (sink?.audio) sink.audio.muted = !sink.audio.muted }
  function up()     { if (sink?.audio) sink.audio.volume = Math.min(1, sink.audio.volume + 0.05) }
}
```

**App mixer** (per-stream sliders — nodes where `isStream`): `ListView { model: Pipewire.nodes; delegate: slider binding node.audio.volumes }`. **Peak meters** (for volume bars/cava-likes): `PwNodePeakMonitor` on a node gives live amplitude per channel. **Default-switcher UI**: list nodes with `isSink`, click → `Pipewire.preferredDefaultAudioSink = node`. **PwLinkGroup** — route streams to sinks (an output-chooser!).

## 15. MPRIS

`import Quickshell.Services.Mpris` — media players, verified:

```qml
Mpris.players                     // ObjectModel of MprisPlayer — live, hotplug
Mpris.playingPlayers              // convenience filtered

// MprisPlayer (per player: firefox, spotify, vesktop, mpv...):
player.trackTitle / trackArtist (use this; trackArtists is deprecated) / trackAlbum / trackAlbumArtist / trackArtUrl
player.position / player.length / player.positionSupported / player.lengthSupported
player.playbackState              // MprisPlaybackState.Playing|Paused|Stopped
player.isPlaying                  // bool (writable only if canTogglePlaying)
player.canPlay / canPause / canControl / canSeek / canGoNext / canGoPrevious / ...
player.loopState                  // MprisLoopState.None|Track|Playlist
player.shuffle                    // bool
player.volume                     // 0..1 (players that support it)
player.rate / minRate / maxRate
player.metadata                   // raw QVariantMap
player.uniqueId / identity / desktopEntry / dbusName
```

A complete media widget:

```qml
ColumnLayout {
  visible: Mpris.players.values.length > 0        // hide when nobody's playing
  Repeater {
    model: Mpris.players
    delegate: RowLayout {
      required property var modelData
      IconImage { source: modelData.trackArtUrl ? modelData.trackArtUrl : "" }  // album art
      ColumnLayout {
        Text { text: modelData.trackTitle }
        Text { text: modelData.trackArtist ; opacity: .6 }
        RowLayout {
          Button { enabled: modelData.canGoPrevious; onClicked: modelData.canGoPrevious && modelData.togglePlaying() /* or next/prev calls */ }
          // control calls: player.next() / prev() / play() / pause() — check can* flags
        }
      }
    }
  }
}
```

## 16. Notifications

`import Quickshell.Services.Notifications` — **implement your own notification daemon** (Tide Island, Noctalia do exactly this):

```qml
// The server — declare capabilities, receive everything:
NotificationServer {
  id: server
  keepOnReload: true                     // ⭐ notification history survives config hot reloads
  persistenceSupported: true             // can persist across shell restarts
  bodySupported: true
  bodyMarkupSupported: true              // allow <b> tags etc.
  bodyHyperlinksSupported: true
  bodyImagesSupported: true
  actionsSupported: true                 // notification buttons!
  actionIconsSupported: true
  imageSupported: true
  inlineReplySupported: true             // reply-from-notification (like messenger apps)

  onNotification: n => {                 // n: Notification object
    // n.appName, n.summary, n.body, n.urgency (Low|Normal|Critical),
    // n.actions (list), n.hasInlineReply, n.image, n.appIcon, n.expireTimeout,
    // n.resident, n.transient, n.hints (raw map)
    n.tracked = true        // keep it in server.trackedNotifications (your history!)
    showPopup(n)
  }
}
```

The `Notification` object methods: `expire()` (timeout now), `dismiss()` (user closed), `sendInlineReply(text)`; actions are `NotificationAction { identifier, text, invoke() }`. `NotificationCloseReason` — Expired/DismissedByUser/DismissedByCommand.

**History/notification center**: everything you set `tracked = true` lands in `server.trackedNotifications` (an ObjectModel) — ListView over it = your notification center. **DND**: just don't call showPopup while your Focus toggle is on. **Toast component** — see recipe §37.

## 17. System Tray (SNI)

```qml
import Quickshell.Services.SystemTray

SystemTray.items            // ObjectModel of SystemTrayItem — LIVE (apps appear/disappear)

// SystemTrayItem (verified):
//  id, title, icon, status (Active|Passive|NeedsAttention), category,
//  tooltipTitle, tooltipDescription,
//  hasMenu, menu (DBusMenuHandle), onlyMenu
//  activate() / secondaryActivate() / scroll(delta, horizontal)
//  display(parentWindow, relX, relY) — QsMenu popup positioning helper
```

```qml
Row {
  Repeater {
    model: SystemTray.items
    delegate: Item {
      required property var modelData
      IconImage { source: modelData.icon; implicitSize: 18 }
      MouseArea {
        onClicked: modelData.activate()
        onRightClicked: modelData.display(window, 0, 0)   // DBusMenu popup!
      }
    }
  }
}
```

`import Quickshell.DBusMenu` — the **DBusMenuItem/QsMenuOpener** types render the app's real menu (the KDE StatusNotifier menu protocol) into QtQuick menu items. `QsMenuHandle`/`QsMenuAnchor` position it. This is how Noctalia/DMS show right-click menus for NM-applet, vesktop tray etc.

## 18. UPower

```qml
import Quickshell.Services.UPower

UPower.onBattery               // bool — discharging?
UPower.displayDevice           // the laptop battery aggregate
UPower.devices                 // all (batteries, peripherals with batteries!)

// UPowerDevice: type, percentage, state, isLaptopBattery, powerSupply, energy,
//               energyCapacity, changeRate, timeToEmpty, timeToFull,
//               healthPercentage, healthSupported, iconName, model, nativePath, ready

PowerProfiles.profile          // PowerProfile.PowerSaver|Balanced|Performance (WRITE!)
PowerProfiles.hasPerformanceProfile
PowerProfiles.degradationReason     // why performance is limited (thermal...)
PowerProfiles.holds             // active profile holds (apps requesting perf)
```

```qml
// battery widget + profile switcher — no TLP, no scripts, no pkexec:
Text { visible: UPower.displayDevice != null
       text: `${Math.round(UPower.displayDevice.percentage)}% ${UPower.onBattery ? "🔋" : "⚡"}` }
ComboBox {
  model: ["power-saver", "balanced", "performance"]
  onActivated: i => PowerProfiles.profile = [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance][i]
}
```

(You run power-profiles-daemon on this machine — this is your island control-center tile, natively.)

## 19. Networking

```qml
import Quickshell.Networking

Networking.devices                 // ObjectModel: WiredDevice + WifiDevice
Networking.backend                 // NetworkManager | Iwd
Networking.wifiEnabled             // WRITE — airplane-mode toggle!
Networking.wifiHardwareEnabled
Networking.connectivity            // None|Portal|Limited|Full
Networking.canCheckConnectivity / checkConnectivity() / connectivityCheckEnabled

// WifiDevice (verified):
wifi.scannerEnabled               // WRITE true → scan; networks list populates
wifi.networks                     // WifiNetwork list (live)
wifi.mode                         // WifiDeviceMode
wifi.signalStrength? → per-network:
// WifiNetwork: ssid? (hidden?), signalStrength, securityType, connected, connectWithPsk(psk)
// WiredDevice: state, "Connected"State etc.
```

A complete WiFi applet: scanner toggle, ListView of `wifi.networks` sorted by `signalStrength`, click → open / `connectWithPsk` dialog for secured ones. Plus `NMSettings` for connection management. Full code in recipe book §40.

## 20. Bluetooth

```qml
import Quickshell.Bluetooth

Bluetooth.defaultAdapter          // BluetoothAdapter
Bluetooth.adapters / Bluetooth.devices

// BluetoothAdapter: powered (WRITE), scanning (WRITE!), discoverable, pairable, devices
// BluetoothDevice (verified):
//  name, deviceName, address, icon, state (BluetoothDeviceState.Connected|Connecting|...),
//  connected (WRITE!), paired, bonding, pairing, trusted, blocked, wakeAllowed,
//  batteryAvailable, battery, adapter
//  connect() / disconnect() / pair() / cancelPair() / forget()
```

Bluetooth control center card = adapter toggle + scan + ListView devices with connect/pair buttons and a battery chip for Buds-style devices. NixOS: `hardware.bluetooth.enable = true` (you have it — saw bluez services in your tmp).

## 21. DesktopEntries

```qml
import Quickshell

DesktopEntries.applications          // ObjectModel of DesktopEntry — every app on the system
DesktopEntries.byId("firefox")
DesktopEntries.heuristicLookup("fire")  // fuzzy by name

// DesktopEntry: id, name, genericName, comment, icon, execString, command (list!),
//               categories, keywords, noDisplay, runInTerminal, workingDirectory, actions[]
// entry.execute()                  — launch it!
// DesktopAction { name, icon, command, execute() }   — e.g. "New Window" actions
```

This + `Quickshell.iconPath(entry.icon)` = a complete app launcher with real icons and search (match `name`/`keywords`/`categories`). §36 has the full recipe.

## 22. Auth stack

### Polkit agent — replace polkit-gnome

```qml
import Quickshell.Services.Polkit

PolkitAgent {
  onNewRequest: req => {                 // AuthFlow object
    // req.message, req.iconName, req.actionId, req.identities (list), req.selectedIdentity,
    // req.isResponseRequired, req.responseVisible (hide for fingerprint?),
    // req.inputPrompt, req.supplementaryMessage, req.failed
    polkitDialog.openFor(req)           // your UI
    // then: req.respond(password)  /  req.cancel()  /  req.selectIdentity(identity)
    // states: isCompleted, isSuccessful, isCancelled
  }
}
```

That's the whole agent. Build one pretty password dialog and your shell replaces hyprpolkitagent/xfce-polkit.

### PAM — authenticate users *from* your shell (lock screens!)

```qml
import Quickshell.Services.Pam

PamContext {
  config: "quickshell-lock"            // pam config NAME (see below)
  configDirectory: "/etc/pam.d"        // where to find it
  user: "fury"
  active: true                         // start auth
  // → message (prompt), messageIsError, responseRequired, responseVisible (password field?)
  onMessageChanged: prompt.text = message
  function tryAuth(password) { respond(password) }
  onCompleted: result => {                // PamResult
    if (result == PamResult.Success) unlock()
  }
}
```

PAM configs from the official module docs — password, fingerprint, or both:

```
# /etc/pam.d/quickshell-lock — password OR fingerprint (fingerprint first):
auth sufficient pam_fprintd.so
auth required pam_unix.so
```

On NixOS: `security.pam.services.quickshell-lock = { ... }` or drop a file via `environment.etc`.

### Greetd — build a graphical greeter!

```qml
import Quickshell.Services.Greetd
// Greetd.available, Greetd.state (GreetdState), Greetd.user
// + session selection / startSession — full display-manager UI in your shell
```

Run quickshell as the greeter session (`services.greetd.settings.default_session.command = "quickshell -c greeter"`), pair with PAM → a completely custom login screen (this is qylock territory — you could build your own next).

---

# PART IV — WAYLAND DEEP-CUTS

## 23. Layershell details

`WlrLayershell` is an **attached** object usable on any window (it's what PanelWindow implements):

- `WlrLayershell.layer`: `WlrLayer.Background | Bottom | Top | Overlay` (Top = above windows, below OS overlays; Overlay = above everything incl. most panels — launchers/locks).
- `WlrLayershell.namespace`: **set this always** — it's the key Hyprland `layer_rule`s match for blur/anim ("quickshell:your-ns" — check with `hyprctl layers`).
- `WlrLayershell.keyboardFocus`: `None | OnDemand (focus when clicked) | Exclusive (always — launcher/lock)`.

Full property list equals PanelWindow's (anchors/margins/exclusiveZone/exclusionMode/aboveWindows/focusable — layershell is where they live; PanelWindow inherits).

## 24. Toplevels

`import Quickshell.Wayland` → `ToplevelManager` — **foreign-toplevel-management**: every window on every compositor (Hyprland, sway, niri...):

```qml
ToplevelManager.toplevels             // ALL windows, cross-compositor
ToplevelManager.activeToplevel       // focused window

// Toplevel: appId, title, parent (transient dialogs), activated,
//           maximized (WRITE), minimized (WRITE!), fullscreen (WRITE), screens
// functions: activate() (focus it)
```

Taskbar/alt-tab that works on any compositor: Repeater over toplevels, icon by appId, click → `toplevel.activate()`, middle-click → `minimized = !minimized`. (Hyprland-specific workspaces? Use §13's toplevels-with-workspace instead.)

## 25. Lockscreens

```qml
import Quickshell.Wayland

WlSessionLock {
  id: lock
  locked: false                // WRITE true → engage ext-session-lock-v1
  secure: false                 // true when the lock took effect everywhere
  // surfaces: QQmlComponent instantiated per screen:
  surface: Component {
    WlSessionLockSurface {
      required property var modelData   // per-screen
      // → contentItem, visible, width, height, screen, color, children
      // build your lock UI here; use PamContext for the password (§22)
    }
  }
}
```

ext-session-lock is THE secure Wayland lock protocol (that's what hyprlock/swaylock use). **You can build a lockscreen in ~100 lines**: WlSessionLock + PamContext + your design. Combine with IdleMonitor (§26) → auto-lock. NixOS: run it via a systemd service or `loginctl`-triggered quickshell IPC — and disable other lock services.

## 26. Idle

```qml
// React to idleness (for auto-lock, screen-off, "away" status):
IdleMonitor {
  enabled: true
  timeout: 300                    // seconds
  respectInhibitors: true         // video players block idle via wayland-idle-inhibit
  onIdle: () => lock.locked = true
  // isIdle (bool, observable)
}

// Keep the screen awake while a condition holds (video playing, fullscreen game):
IdleInhibitor {
  window: myPanelWindow           // optionally tie to a window
  enabled: player.isPlaying       // ← your media widget inhibits idle while playing!
}
```

## 27. BackgroundEffect

```qml
import Quickshell.Wayland

// Request COMPOSITOR blur behind a region of your window (hyprland-focus-grab-style protocol;
// needs compositor support — Hyprland does):
BackgroundEffect {
  window: myPanelWindow
  blurRegion: Region { item: blurredRect; shape: RegionShape.Box; intersection: RegionShape.Box }
}
```

`blurRegion` is a `PendingRegion` — the compositor blurs what's behind that shape (like `layer_rule blur` but targeted at *part* of your surface, from inside the shell). Pair with a semi-transparent `Rectangle` = real frosted-glass without CSS hacks.

## 28. Screencopy / ShortcutInhibitor / i3

- `ScreencopyView` — capture screen content (previews, thumbnails — Tide Island's workspace overview uses compositor APIs around this).
- `ShortcutInhibitor` — block compositor shortcuts while a window is focused (game mode for *your* windows).
- **i3/sway**: `import Quickshell.I3` → `I3` singleton mirroring the Hyprland API (workspaces, nodes, IPC) — your shell can be cross-WM. Raw: `I3IpcListener`.

---

# PART V — WIDGET CRAFT

## 29. Widgets toolkit

`import Quickshell.Widgets` (verified from headers):

```qml
// IconImage — icon-theme-aware image (falls back to empty, not purple boxes, with iconPath):
IconImage { source: Quickshell.iconPath("audio-volume-high", "") ; implicitSize: 22 }

// ClippingRectangle / ClippingWrapperRectangle — rounded/complex-clipped content:
ClippingWrapperRectangle {
  radius: 10
  IconImage { source: player.trackArtUrl }     // round album art (FAQ's official answer)
}

// Wrapper family (§6):
WrapperItem / WrapperRectangle / WrapperMouseArea / MarginWrapperManager
// e.g. WrapperRectangle { margin: 6; Rectangle { ... } }  — auto implicit/actual sizing
// MarginWrapperManager: margin, extraMargin, per-side overrides, resizeChild, implicit sizes

// QsMenu — QtQuick-Controls Menu driven by DBusMenu (tray menus!):
// QsMenuOpener { menu: trayItem.menu } / QsMenuEntry { ... } — see §17
```

### Region — input masks (click-through, holes)

```qml
// PendingRegion on window.mask — define WHERE the window accepts input:
mask: Region {
  shape: RegionShape.Box | RegionShape.Ellipse
  intersection: Intersection.Add | Subtract | Intersect
  item: someItem                // or manual x/y/width/height (+ corner radii, per-corner!)
}
```

Classic uses: bar that only reacts over its drawn content; an island whose gap doesn't block clicks below; overlay that passes everything except buttons.

### MultiEffect (QtQuick.Effects) — the effects engine

```qml
import QtQuick.Effects
MultiEffect {
  anchors.fill: parent
  source: contentItem
  shadowEnabled: true; shadowBlur: 1.0; shadowColor: "#80000000"  // FAQ's drop-shadow answer
  blurMax: 32; blur: 0.5                 // live blur INSIDE the shell (compositor-independent!)
  saturation: 1.2; brightness: 0.1       // image grading
}
```

`RectangularShadow` (QtQuick) — cheap rectangular/rounded/circular shadows.

## 30. QtQuick Controls

`import QtQuick.Controls` — Buttons, Sliders, Popup, ToolTip, ComboBox, etc. Quickshell sets **Fusion style by default** for consistency (`pragma RespectSystemStyle` to follow the system, or `//@ pragma Env QT_QUICK_CONTROLS_STYLE = <style>` to pick). Use `pragma UseQApplication` if you need QtWidgets-dependent styles (qqc2-desktop-style).

Design-system theming: set a **Theme singleton** (§41) and style the Controls with it — don't fight per-item colors in 40 places. For full custom looks, most shells skip Controls for hot paths and compose MouseArea+Rectangle (like Tide Island does) — Controls for dialogs/settings, custom widgets for the bar.

## 31. Effects & animations

- **Behavior** — animate any property change:

```qml
Rectangle {
  color: mouseArea.containsMouse ? hover : normal
  Behavior on color { ColorAnimation { duration: 120 } }
}
Item { Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } } }
```

- **EasingCurve** (Quickshell) — pre-packaged curves for NumberAnimation `easing` — spring-feel without physics: pair with `Easing.Bezier` curves from your theme.
- **States & Transitions** — for island-style state machines (collapsed→expanded) — Tide Island is literally States+Transitions+Behaviors.
- **SequentialAnimation/ParallelAnimation** — orchestrate; `PauseAnimation` for choreography (staggered popins).
- FAQ limits: don't animate everything; animate *state changes*, keep 100–300ms; use `easing.type: Easing.OutCubic`-ish for enters.

## 32. ColorQuantizer — matugen built-in!

```qml
// services/Wallpaper.qml
pragma Singleton
import QtQuick
import Quickshell

Singleton {
  id: root
  property url source: "file://" + Quickshell.statePath("wallpaper")
  // ColorQuantizer — pull a palette FROM the wallpaper image:
  ColorQuantizer {
    id: quant
    source: root.source             // image URL
    depth: 1.2                      // color diversity
    rescaleSize: 256                // sample efficiently
    // imageRect: optional sub-region
    // → colors: QList<QColor> — dominant-first
  }
  readonly property color accent: quant.colors[0] ?? "#7aa2f7"
  readonly property color bg:     quant.colors[1] ?? "#1a1b26"
  readonly property color text:  quant.colors[2] ?? "#c0caf5"
}
```

Change wallpaper → quant re-runs → **your whole shell recolors via bindings**. This is the matugen effect with zero external processes; combine with pywal/matugen writes to `Quickshell.statePath()` + FileView if you also want to color *other* apps.

---

## 33. Pragmas & environment

All from the official Advanced page:

```qml
//@ pragma Env QT_QUICK_CONTROLS_STYLE = Fusion   // engine env (Quickshell only, not children)
//@ pragma DefaultEnv VAR = VAL                    // set-if-unset
//@ pragma UseQApplication                         // QtWidgets styles support
//@ pragma NativeTextRendering                     // system text rasterizer
//@ pragma IgnoreSystemSettings
//@ pragma RespectSystemStyle                      // don't force Fusion
//@ pragma DropExpensiveFonts                     // skip woff/woff2 (perf!)
//@ pragma IconTheme Papirus                      // icon theme
//@ pragma AppId com.fury.shell                   // wayland app id
//@ pragma ShellId fury-shell                     // instance identity
//@ pragma DataDir "$BASE/fury-shell"              // + StateDir, CacheDir; $BASE = XDG dir
```

- **If/Endif** (C-preprocessor for QML!):

```qml
//@ if env("XDG_CURRENT_DESKTOP") == "Hyprland"
//   ...hyprland-only code...
//@ endif
// conditions may use hasVersion(), hasQtVersion(), env(), isEnvSet()
```

- **`//@ pragma Internal`** on a file — hide it from other modules.
- Env vars: `QS_DISABLE_FILE_WATCHER`, `QS_CONFIG_PATH`, `QS_NO_XINERAMA_STRUTS` (X11 bar hacks), `QS_NO_RELOAD_POPUP`, `QS_DISABLE_CRASH_HANDLER`, `QS_ICON_THEME`, `QS_APP_ID`, `QS_DROP_EXPENSIVE_FONTS`.

---

## 34. Nix packaging

Patterns from nixpkgs (noctalia-shell, dms-shell package Quickshell *configs*):

```nix
# my-shell/package.nix — a pure-QML shell: stdenvNoCC + wrap quickshell
{ stdenvNoCC, quickshell, makeWrapper, ... }:
stdenvNoCC.mkDerivation {
  pname = "my-shell"; version = "1.0";
  src = ./.;
  nativeBuildInputs = [ makeWrapper ];
  installPhase = ''
    mkdir -p $out/share/quickshell/my-shell
    cp -r . $out/share/quickshell/my-shell/
    mkdir -p $out/bin
    makeWrapper ${quickshell}/bin/quickshell $out/bin/my-shell \
      --add-flags "-c my-shell"
  '';
}
```

```nix
# runtime helpers pattern (like noctalia):
qtWrapperArgs = [ "--prefix PATH : ${lib.makeBinPath [ brightnessctl pamixer grim slurp wl-clipboard ] }" ];
# or a wrapper script in shell.qml's PATH via --prefix
```

```nix
# configuration.nix
environment.systemPackages = [ (pkgs.callPackage ./my-shell { }) pkgs.quickshell ];
# autostart (Hyprland Lua): hl.exec_cmd("my-shell")
# or systemd: systemd.user.services."my-shell" → graphical-session.target
```

For **C++ extension** shells (like Tide Island): stdenv.mkDerivation + cmake + qt6 modules + `qt_add_qml_module`-aware build — see the Tide Island guide's derivation.

---

# PART VII — THE BIG RECIPE BOOK

## 35. Recipe: a complete bar

An opinionated, fully-commented, real bar — workspaces, tray, clock, audio, battery, network, power — using the services properly:

```qml
// shell.qml
//@ pragma IconTheme Papirus
//@ pragma AppId com.fury.bar
import Quickshell
import QtQuick
import qs.services
import qs.widgets

Scope {
  id: root

  // ── one window per screen ──
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: bar
      required property var modelData
      screen: modelData

      anchors { top: true; left: true; right: true }
      exclusiveZone: 38
      implicitHeight: 38
      color: "transparent"

      WlrLayershell.namespace: "fury-bar"     // layer_rule blur target

      // frosted body — transparent window + rounded rect (§6 FAQ)
      Rectangle {
        anchors.fill: parent
        color: Theme.bg
        radius: 0

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 12; anchors.rightMargin: 12
          spacing: 8

          // LEFT: workspaces (Hyprland service)
          Repeater {
            model: Hyprland.workspaces
            delegate: WorkspaceDot {
              required property var modelData
              ws: modelData
            }
          }

          Item { Layout.fillWidth: true }    // spacer

          // CENTER: active window title (cross-compositor toplevels)
          Text {
            text: ToplevelManager.activeToplevel?.title ?? ""
            color: Theme.text; elide: Text.ElideRight
            Layout.maximumWidth: 400
          }

          Item { Layout.fillWidth: true }

          // RIGHT: modules
          TrayWidget {}                    // §17
          AudioWidget {}                   // §14 (bind, don't poll)
          BatteryWidget {}                 // §18
          NetWidget {}                      // §19 (WifiDevice state)
          ClockWidget {}                    // §12 (SystemClock)

          PowerButton {                     // §39
            onClicked: powerMenu.open(this)
          }
        }
      }
    }
  }
}
```

Key discipline this bar teaches: **services in singletons** (qs/services/Audio.qml etc.), **widgets dumb** (bind only), one Process-free design except deliberate streamers.

## 36. Recipe: app launcher

```qml
// modules/Launcher.qml — Overlay layer, exclusive focus, fuzzy search
PanelWindow {
  id: launcher
  visible: false
  anchors { top: true; left: true; right: true }       // top strip, width = screen
  exclusionMode: ExclusionMode.Ignore                // overlay, no reserve
  implicitHeight: 420
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "fury-launcher"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  color: "#b0000000"

  property string query: ""

  // ── filtered app list (reactive: DesktopEntries × query) ──
  readonly property var apps: Quickshell.shellRoot ? [...] // see below
  // (compute: DesktopEntries.applications filtered by name/keywords.contains(query))

  ColumnLayout {
    anchors.fill: parent; anchors.margins: 40

    Rectangle {   // search field — pure QML (or TextField with Controls)
      implicitHeight: 48; radius: 12; color: "#2a2b31"
      RowLayout {
        TextInput {
          id: input
          font.pixelSize: 18; color: "white"
          onTextChanged: launcher.query = text
          Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) launcher.visible = false
            if (e.key === Qt.Key_Return) { launcher.launchCurrent(); launcher.visible = false }
          }
        }
      }
    }

    ListView {
      id: list
      Layout.fillWidth: true; Layout.fillHeight: true
      clip: true
      model: launcher.filteredApps()
      delegate: RowLayout {
        required property var modelData
        spacing: 12
        IconImage { source: Quickshell.iconPath(modelData.icon, "application-x-executable"); implicitSize: 32 }
        Text { text: modelData.name; color: "white" }
        Text { text: modelData.comment ?? ""; color: "#888"; font.pixelSize: 11 }
        TapHandler { onTapped: { modelData.execute(); launcher.visible = false } }
      }
    }
  }

  function filteredApps() {
    const q = query.toLowerCase().trim();
    if (!q) return DesktopEntries.applications.values.slice(0, 12);
    return DesktopEntries.applications.values
      .filter(a => !a.noDisplay)
      .filter(a => a.name.toLowerCase().includes(q)
                || (a.keywords ?? []).some(k => k.toLowerCase().includes(q)))
      .slice(0, 12);
  }

  onVisibleChanged: if (visible) { input.forceActiveFocus(); input.text = ""; query = "" }

  // register-only-one grab dismissal:
  HyprlandFocusGrab {   // click outside → close (Hyprland; use focus loss elsewhere)
    active: launcher.visible
    // region covering launcher → onCleared → visible = false
  }
}
// shell.qml: IpcHandler { target: "launcher"; function toggle() { launcher.visible = !launcher.visible } }
// bind: quickshell ipc launcher toggle
```

## 37. Recipe: notification daemon + toasts

```qml
// services/Notifications.qml
pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
  id: root
  property var toasts: []                    // stack of shown notifications
  property int maxToasts: 3
  property bool dnd: false

  NotificationServer {
    id: server
    keepOnReload: true; persistenceSupported: true
    bodySupported: true; actionsSupported: true; imageSupported: true; inlineReplySupported: true

    onNotification: n => {
      n.tracked = true                       // history keeps it
      if (!root.dnd) root.toasts.push(n)    // pop only when allowed
    }
  }

  function dismiss(n) { n.dismiss(); toasts = toasts.filter(x => x !== n) }
  readonly property var history: server.trackedNotifications
}
```

```qml
// modules/Toasts.qml — right side stack, auto-expire
PanelWindow {
  anchors { top: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  implicitWidth: 360
  implicitHeight: toastsCol.implicitHeight + 20
  WlrLayershell.namespace: "fury-notifs"
  color: "transparent"

  ColumnLayout {
    id: toastsCol
    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
    spacing: 8
    Repeater {
      model: NotificationsS.toasts
      delegate: Rectangle {
        required property var modelData
        radius: 12; color: "#e61c1c1e"; implicitHeight: box.implicitHeight + 16
        Behavior on implicitHeight { NumberAnimation { duration: 150 } }
        ColumnLayout {
          id: box; width: parent.width - 16
          Text { text: modelData.appName; color: Theme.accent }
          Text { text: modelData.summary; color: "white"; font.bold: true }
          Text { text: modelData.body; color: "#ccc"; wrapMode: Text.Wrap
                 textFormat: Text.RichText          // markupSupported
                 Layout.fillWidth: true }
          Row {   // action buttons!
            Repeater {
              model: modelData.actions
              delegate: Button {
                required property var modelData
                text: modelData.text
                onClicked: { modelData.invoke(); NotificationsS.dismiss(parent.parent.parent.modelData) }
              }
            }
          }
        }
        // auto-expire respecting server timeout:
        Timer {
          interval: modelData.expireTimeout > 0 ? modelData.expireTimeout : 5000
          onTriggered: modelData.expire()
        }
      }
    }
  }
}
```

## 38. Recipe: OSD

```qml
// modules/Osd.qml — volume/brightness popup, auto-hiding
PanelWindow {
  id: osd
  visible: false
  anchors { bottom: true }
  exclusionMode: ExclusionMode.Ignore
  implicitHeight: 200; implicitWidth: 80
  WlrLayershell.namespace: "fury-osd"

  property string icon: ""
  property real level: 0
  property var hideTimer: Timer { interval: 1500; onTriggered: osd.visible = false }

  function show(icon, level) {
    osd.icon = icon; osd.level = level; visible = true; hideTimer.restart()
  }

  Rectangle {
    anchors.centerIn: parent
    width: 64; height: 160; radius: 32; color: "#cc1c1c1e"
    ColumnLayout {
      anchors.centerIn: parent
      IconImage { source: osd.icon; implicitSize: 28 }
      Rectangle {   // vertical level bar
        width: 8; radius: 4
        height: 100 * osd.level
        color: Theme.accent; Behavior on height { NumberAnimation { duration: 80 } }
      }
    }
  }
}

// wiring — no scripts, react to service changes:
// services/Audio.qml: onVolumeChanged => Osd.show(iconFor(vol), vol)
//   brightness: Process("brightnessctl set +5%") or ddcutil; parse, show, set
// IpcHandler { target: "osd"; function volumeUp() { AudioS.up() } }
```

## 39. Recipe: power menu

```qml
// modules/PowerMenu.qml
PopupWindow {
  id: menu
  anchor.item: powerButton; anchor.edges: Edges.Bottom
  grabFocus: true; visible: false
  WlrLayershell.namespace: "fury-power"     // PopupWindow still namespaces

  ColumnLayout {
    PowerEntry { icon: "system-lock-screen";  label: "Lock";    onClicked: { lock.locked = true; menu.visible = false } }
    PowerEntry { icon: "system-log-out";      label: "Logout";  onClicked: Hyprland.dispatch('hl.dsp.exit()') }
    PowerEntry { icon: "system-reboot";       label: "Reboot";  onClicked: Quickshell.execDetached(["systemctl","reboot"]) }
    PowerEntry { icon: "system-shutdown";     label: "Power off"; onClicked: Quickshell.execDetached(["systemctl","poweroff"]) }
    PowerEntry { icon: "system-suspend";      label: "Suspend"; onClicked: Quickshell.execDetached(["systemctl","suspend"]) }
  }
}
// Lock: the WlSessionLock from §25 — for a real session lock, not just a fake overlay.
```

## 40. More recipes (compact)

**Right-click desktop menu** — full-screen transparent Background-layer PanelWindow with `mask: Region { item: desktopArea }`, Menu on right click. Or QsMenu.

**Clipboard picker** (cliphist):

```qml
Process { id: listProc; command: ["cliphist", "list"] ; stdout: SplitParser { onRead: l => model.append(l) } }
Process { id: pickProc; command: ["bash","-c", `cliphist decode <<< ${JSON.stringify(sel)} | wl-copy`]
          running: false; onExited: launcher.visible = false }
// grid ListView over parsed entries, Enter → decode|wl-copy
```

**Calendar** — `SystemClock { precision: Minutes }` + Grid of days; or evolve-data-server via GIO for real events (noctalia does this with pygobject — heavier).

**Cava visualizer** — the FAQ-perfect SplitParser case:

```qml
Process {
  command: ["cava", "-p", "--raw"]     // raw frames of bar heights
  running: barVisible
  stdout: SplitParser {
    splitMarker: "\n"                  // or ; per-frame per-bar
    onRead: frame => barsModel = frame.split(";").map(parseFloat)
  }
}
// Canvas or Row of Rectangles rendering barsModel — bind, don't paint manually
```

**Lockscreen** — §25 + §22 (PamContext) + your wallpaper (ColorQuantizer for themed clock). **Greeter** — §22 greetd. **Screenshot UI** — grim/slurp via Process + Satty annotation window (FloatingWindow) + portal ScreencopyView for previews.

## 41. Patterns

1. **Singletons for services & theme** (qs/services/*): one Audio.qml, Theme.qml, Notifications.qml... windows/widgets import qs.services and bind. This is how Noctalia/Caelestia/Tide structure.
2. **LazyLoader** for heavy windows (overview, launcher, lock) — load on first open, keep loaded; `Loader` for visual subtrees; FAQ memory advice.
3. **States & Transitions** for expandable widgets (islands!) — collapsed/expanded/peek states.
4. **Variants for windows; Repeater for widgets** — never the reverse.
5. **Feature-gate**: `Quickshell.hasVersion(0,3)` / `//@ if` pragmas for cross-version configs.
6. **One process** — services instead of scripts: the FAQ's loudest advice. Process only for: streamers (cava), one-shots (grim), WM fallbacks.
7. **Persist with FileView+JsonAdapter into statePath** — never configPath for state (ro in Nix store!).
8. **Zero-size debugging**: always set implicitWidth/Height on custom containers; log window warnings.

## 42. Debugging & workflow

- Run `quickshell -p .` from a terminal — **read the WARN lines**, they're excellent (undefined refs, binding loops, zero sizes).
- `console.log` works; errors show file:line of the QML.
- Hot reload breaks state — wrap fragile things in `keepOnReload` (notifications) or persist to statePath; `config.unload`-style prep via `Component.onDestruction`.
- LSP: **qmlls** + Quickshell's generated types — autocomplete & types for every import (that's why qs.* imports and no root:/ imports!).
- Community: Matrix #quickshell:outfooxed.me, Discord. Docs: quickshell.org/docs/v0.3.0 (guide + full type reference). Shells to read: **caelestia-dots/shell**, **end-4/dots-hyprland**, Noctalia, DMS, **your Tide-island checkout** (which is a masterclass in all of this — 3.1k-line window state machine, IpcHandlers, service usage).

---

*Companion guides: `HYPRLAND-NIXOS-LUA-GUIDE.md` · `MANGOWC-RICING-GUIDE.md` · `TIDE-ISLAND-NIXOS-GUIDE.md` (+ the nix implementation in `~/Projects/tide-island-nix/`)*

---

# PART VIII — GAPS CLOSED (v0.3.0 verified appendices)

> Every property/function below was re-checked against `quickshell.org/docs/v0.3.0/types/...`. Where the shorthand name differs from the real API, the real name is given first.

## 43. CLI complete: list/kill/log/ipc + instance selection + env

Manpage ground truth: `qs(1)` / `quickshell(1)` 0.3.0-1, plus `src/launch/{parsecommand,command}.cpp` and the IpcHandler type page.

```bash
# ── launch ──
qs                                  # default config
qs -c myshell                       # named config (~/.config/quickshell/myshell/shell.qml)
qs -p ~/dev/myshell                 # any path (folder → shell.qml appended; or a bare .qml file)
qs -p ~/dev/myshell/shell.qml
qs -n -c myshell                    # --no-duplicate: exit if this config already running
qs -d -c myshell                    # --daemonize: fork + setsid, parent waits on pipe for startup
qs -V; qs -h                        # --version / --help
qs -v; qs -vv                       # INFO then DEBUG internal logs
qs --log-times --log-rules "qs.*=true" --no-color   # timestamps, QT_LOGGING_RULES, NO_COLOR respects

# ── instances ──
qs list                             # ID, PID, shell-id, config path, launch time
qs list --json                      # machine-readable array of instance metadata
qs log                              # dump .qslog (binary log format decoded)
qs log --follow --lines 200         # follow + tail (LogFollower)
qs kill                             # kill selected instance (IpcKillCommand → EngineGeneration::quit())
qs kill -c myshell                  # select by config (default strategy)

# ── instance selection (addInstanceSelection) ──
qs --id <prefix> ipc ...            # by instance ID prefix (fails if ambiguous)
qs --pid <pid> ipc ...              # by PID (by-pid symlink)
qs -c myshell ipc ...               # by config path hash (by-path symlink; oldest wins unless --newest)
qs --newest -c myshell ipc ...      # newest instance of that config
qs --any-display ipc ...            # skip display-connection filter (X11/Wayland match by default)

# ── ipc (talks to IpcHandler targets over ipc.sock in the instance runtime dir) ──
qs ipc show                                         # list targets + signatures
qs ipc call <target> <fn> [args...]                 # max 10 args; typed: string/int/bool/real/color
qs ipc callJson <target> <fn> '<json-string>'       # single-string passthrough (commas/brackets survive)
qs ipc prop get <target> <property>                 # read IPC-compatible property (string/int/bool/real/color)
qs ipc wait <target> <signal>                       # one-shot: block until signal fires
qs ipc listen <target> <signal>                     # stream: print every emission
qs msg ...                          # DEPRECATED alias of `qs ipc call`
```

IpcHandler typing rules (from the type page — enforced, not advisory):

```qml
IpcHandler {
  target: "rect"; enabled: true     // target required + unique, changeable at runtime
  function setColor(c: color): void { rect.color = c }   // color accepts "orange", "#ff0000", "#AARRGGBB"
  function getColor(): color { return rect.color }       // color returns "#AARRGGBB"
  function setAngle(a: real): void { rect.rotation = a } // real parses "40.5"
  function setN(n: int): void { ... }                    // int must parse as integer
  function setB(b: bool): void { ... }                   // bool: "true"/"false"/int (0=false, else true)
  signal radiusChanged(n: int)                           // signals: 0 or 1 arg of the same 5 types
}
```

```bash
qs ipc show
# target rect
#   function setColor(color: color): void
#   function getColor(): color
#   signal radiusChanged(newRadius: int)
qs ipc call rect setColor orange
qs ipc call rect getColor            # → #ffffa500
qs ipc prop get rect radius
qs ipc wait rect radiusChanged       # one emission then exit
qs ipc listen rect radiusChanged     # every emission
qs ipc callJson jsonTarget sendJson '[{"a": 1},{"b": 2}]'  # use when JSON has commas/brackets
```

Env + flags:

```
-p/--path TEXT  ↔ QS_CONFIG_PATH   # file or folder. Excludes --config/--manifest.
-c/--config TEXT ↔ QS_CONFIG_NAME  # Excludes --path.
-m/--manifest TEXT ↔ QS_MANIFEST   # [DEPRECATED] manifest path. Excludes --path. Do not use for new shells.
--no-duplicate/-n, --daemonize/-d, --debug PORT + --waitfordebug, --any-display
QS_DISABLE_FILE_WATCHER=1          # no hot reload (CI/tests)
QS_NO_XINERAMA_STRUTS=1            # X11 bar-position hack (may fix or worsen — WM-dependent)
QS_NO_RELOAD_POPUP=1               # no reload popup (or call Quickshell.inhibitReloadPopup() in reloadCompleted/reloadFailed)
QS_DISABLE_CRASH_HANDLER=1         # disable crash handler + relaunch system
QS_CRASHREPORT_URL=<url>           # crash reporter points here instead of upstream tracker
QS_ICON_THEME / QS_APP_ID / QS_DROP_EXPENSIVE_FONTS=1  # same as the IconTheme/AppId/DropExpensiveFonts pragmas
QT_QUICK_CONTROLS_STYLE, NO_COLOR, QT_LOGGING_RULES (via --log-rules)
```

## 44. Variants deep-dive: model/delegate/instances + reload scope

Type: `Variants : Reloadable`, `import Quickshell`. Three props only: `model: list<variant>`, `delegate: Component` (default property), `instances: list<QtObject>` (readonly).

```qml
Variants {
  model: Quickshell.screens        // ANY list: screens, Hyprland.monitors, ["top","bottom"], ScriptModel.values
  // delegate is the DEFAULT property — these two are identical:
  // delegate: Component { PanelWindow { ... } }
  PanelWindow {                    // implicit delegate
    required property var modelData   // injected per instance; duplicates in model create ONE instance
    screen: modelData
  }
}
// Elsewhere (e.g. IPC debug): variants.instances.length — current live delegate objects
```

Rules:

- Non-Item only. Visual repeats inside a window → `Repeater`/`ListView`. Window/object repeats → `Variants`.
- Delegate is a `Component`: 0..N instances. Ids inside don't exist outside. Hoist state to root/singleton (§4).
- `instances` is readonly — inspect, never assign.
- Reload scope: `Variants` + `Scope` are `Reloadable`. `Scope` = "set `reloadableId` for all children" (docs verbatim). Visible Items ignore it; non-visual trees use it.
- Stable identity across hot reloads: `reloadableId: "myWindow"` inside a variant branch matches old→new revision per-variant (see `Reloadable.reloadableId`). Without it, reload may recreate windows and drop transient state.
- Known bug (still on the type page): mutating the variant set *during* instantiation fails to reload children. Don't add/remove model entries from inside a delegate's `Component.onCompleted`.

```qml
Variants {
  model: Quickshell.screens
  Scope {                          // reload-scope boundary: children match per-variant on reload
    PanelWindow {
      required property var modelData
      reloadableId: "bar"          // stable per-screen identity
      screen: modelData
    }
  }
}
```

## 45. SystemClock precision zeroing rules

Type: `SystemClock`, `import Quickshell`. Props: `precision`, `enabled`, `date: date`, `hours/minutes/seconds: int`.

- `precision: SystemClock.Seconds` (default) | `Minutes` | `Hours`.
- Zeroing: `minutes` is **0 when precision is Hours**. `seconds` is **0 when precision is Hours or Minutes**. `hours` always live.
- Updates land within ±50ms of the wall-clock edge (before OR after). Never construct `new Date()` for display — bind `clock.date` + `Qt.formatDateTime(clock.date, "hh:mm:ss")` or you'll be off by up to a second.
- `enabled: false` pauses.

```qml
SystemClock { id: c1; precision: SystemClock.Minutes }  // c1.seconds === 0 always
SystemClock { id: c2; precision: SystemClock.Hours }    // c2.minutes === 0, c2.seconds === 0
Text { text: Qt.formatDateTime(c1.date, "hh:mm ddd MMM d") }
```

## 46. Process full surface

Type: `Process : QtObject`, `import Quickshell.Io`. Props: `command: list<string>`, `running: bool`, `workingDirectory: string`, `environment: object`, `clearEnvironment: bool`, `stdinEnabled: bool` (default false), `stdout/stderr: DataStreamParser`, `processId: variant` (null when not running). Signals: `started()`, `exited(exitCode: int, exitStatus)`. Functions: `exec(ctx)`, `signal(sig: int)`, `write(data: string)`, `startDetached()`.

- `running=false` sends SIGTERM. For SIGKILL: `proc.signal(9)`. Process dies with quickshell unless detached.
- `stdinEnabled` must be true *before* start; if false, stdin is closed and `write()` is a permanent no-op even if you flip it later.
- `write()` no-ops when not running.
- No shell: `["echo hello"]` is one argv → fails. Use `["bash","-c","..."]` for pipes.
- `exec()` overloads: list OR object `{command, environment, clearEnvironment, workingDirectory}` — equivalent to set fields + `running=true`, killing the current run first.
- `clearEnvironment: true` → only `environment` survives; `null` value *passes through* the system value instead of removing it (inverted vs default where `null` removes).
- `startDetached()` = `Quickshell.execDetached()` — untracked, `running` stays false, survives reload/quit. Use for launchers (`entry.execute()` covers apps; detached covers scripts).
- Parsers: `StdioCollector` (whole output, `onStreamFinished: this.text`), `SplitParser` (`splitMarker` default `"\n"`, `waitForEnd`), `DataStream`/`DataStreamParser` for binary. Null parser = channel closed, late-attached parser gets nothing.

```qml
Process {
  id: p
  command: ["bash","-c","greetd --help | head -20"]
  stdinEnabled: true
  stdout: StdioCollector { onStreamFinished: out.text = this.text }
  stderr: SplitParser { onRead: data => console.warn(data) }
  onStarted: console.log("pid", processId)
  onExited: (code, status) => console.log("exit", code, status)
  Component.onCompleted: p.exec({ command: ["sh","-c","echo hi"], workingDirectory: "/tmp" })
  function send(s) { write(s + "\n") }
  function kill9() { signal(9) }
}
```

## 47. Greetd + GreetdState greeter recipe

Singleton `Greetd`, `import Quickshell.Services.Greetd`. Props: `available: bool`, `user: string`, `state: GreetdState`. Functions: `createSession(user: string)`, `respond(response: string)` (only after `authMessage` with `responseRequired`), `launch(cmd: list<string>)` / `launch(cmd, env: list<string>)` / `launch(cmd, env, quit: bool)`, `cancelSession()`. Signals: `authMessage(message, error, responseRequired, echoResponse)`, `authFailure(message)`, `readyToLaunch()`, `launched()`, `error(error)`. States: `Inactive, Authenticating, ReadyToLaunch, Launching, Launched`.

- `launch` requires `ReadyToLaunch`. After greetd ACKs, quit ASAP — animate *before* `launch()`; `launched` fires right before auto-exit (only when `quit` true).
- `error` + `responseRequired` are mutually exclusive in `authMessage`. Recoverable errors (bad fingerprint read) arrive as `authMessage(error=true)`; fatal (bad password) arrives as `authFailure` and the session ends.
- `echoResponse` → password field (`false`) vs username/OTP (`true`).

```qml
// services/Greeter.qml — singleton driving a greeter config (run as default_session.command)
pragma Singleton
import QtQuick
import Quickshell.Services.Greetd

QtObject {
  id: root
  property string prompt: ""
  property bool secret: true
  property string error: ""

  function login(user, sessionCmd: list<string>) { Greetd.createSession(user); pendingSession = sessionCmd }
  property var pendingSession: ["Hyprland"]

  Connections {
    target: Greetd
    function onAuthMessage(message, error, responseRequired, echoResponse) {
      root.prompt = message; root.secret = !echoResponse; root.error = error ? message : ""
    }
    function onAuthFailure(message) { root.error = message }
    function onReadyToLaunch() { Greetd.launch(root.pendingSession) }
  }
  function answer(t) { Greetd.respond(t) }
}
// UI: Text { text: Greeter.prompt }; TextInput { echoMode: Greeter.secret ? TextInput.Password : TextInput.Normal
//   onAccepted: Greeter.answer(text) }; Text { text: "state: " + Greetd.state + (Greetd.available ? "" : " (no socket)") }
```

NixOS/greetd wiring: `services.greetd.settings.default_session.command = "quickshell -c greeter"` (or `qs -p ...`), greeter runs as `greeter` user, needs `Greetd.available` true (socket present).

## 48. Menus end-to-end: DBusMenu + QsMenuOpener/Handle/Anchor/Entry

- `DBusMenuHandle : QtObject` (uncreatable): `menu: DBusMenuItem` (readonly root).
- `DBusMenuItem : QsMenuEntry` (uncreatable): `menuHandle: DBusMenuHandle`, `updateLayout()`, `layoutUpdated()`. Call `updateLayout()` when a tray app's menu goes stale.
- `QsMenuEntry : QsMenuHandle` (uncreatable): `text, icon (url for Image.source), enabled, isSeparator, hasChildren, buttonType: QsMenuButtonType, checkState (Qt.CheckState)`, `triggered()`, `display(parentWindow, relX, relY)`.
- `QsMenuOpener`: `menu: QsMenuHandle` → `children: ObjectModel<QsMenuEntry>` (readonly). One opener per submenu level.
- `QsMenuHandle`: `menuChanged()` only. `QsMenuAnchor`: `menu: QsMenuHandle`, `anchor: PopupAnchor` (readonly — set sub-props `anchor.window/item/edges/gravity`), `visible: bool` (readonly), `open()`, `close()`, `opened()`, `closed()`. Anchor snapshot at `opened()` wins; later anchor edits don't reposition.

Tray-menu recipe (platform menu, no custom styling):

```qml
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.DBusMenu

Item {
  id: root
  required property var trayItem   // SystemTrayItem
  QsMenuAnchor {
    id: menuAnchor
    menu: root.trayItem.menu
    anchor.window: bar             // your PanelWindow
    anchor.edges: Edges.Bottom
  }
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: e => {
      if (e.button === Qt.RightButton && root.trayItem.hasMenu) menuAnchor.open()
      else root.trayItem.activate()
    }
  }
}
```

Custom-styled menu recipe (QsMenu opener tree):

```qml
QsMenuOpener { id: opener; menu: trayItem.menu }
ColumnLayout {
  Repeater {
    model: opener.children
    delegate: RowLayout {
      required property var modelData   // QsMenuEntry (really DBusMenuItem)
      visible: !modelData.isSeparator
      Image { source: modelData.icon; sourceSize.width: 16; sourceSize.height: 16 }
      Text { text: modelData.text; opacity: modelData.enabled ? 1 : 0.4 }
      TapHandler { enabled: modelData.enabled; onTapped: modelData.triggered() }
      // submenu: QsMenuOpener { menu: modelData } shown when modelData.hasChildren
    }
  }
}
```

## 49. Networking: NetworkDevice + WiredDevice + Network + NMSettings

- `NetworkDevice` (uncreatable): `name, address (XX:..), type: DeviceType, state: ConnectionState, connected: bool, autoconnect: bool` (writable), `networks: ObjectModel<Network>`, `disconnect()`. Check `type` to downcast to `WifiDevice`/`WiredDevice`.
- `WiredDevice : NetworkDevice`: `hasLink: bool` (cable), `linkSpeed: int` (Mb/s), `network: Network` (null unless `hasLink`).
- `Network` (uncreatable): `name, connected, known, state, stateChanging, device`, `nmSettings: list<NMSettings>` (NM backend only), `connect()`, `connectWithSettings(NMSettings)`, `disconnect()`, `forget()`, `connectionFailed(reason: ConnectionFailReason)`. WiFi instances are really `WifiNetwork`.
- `WifiDevice : NetworkDevice`: `mode: WifiDeviceMode` (readonly), `scannerEnabled: bool` (writable — true = scanning; networks list is empty/inert until you enable it!). `networks` holds `WifiNetwork`.
- `WifiNetwork : Network`: `signalStrength: real` (0..1), `security: WifiSecurityType`, `connectWithPsk(psk: string)` — only for `WpaPsk/Wpa2Psk/Sae`; call plain `connect()` first so saved secrets get a chance (avoids needless password prompts); wrong PSK → `connectionFailed(NoSecrets)`.
- `NMSettings` (uncreatable): `uuid/id: string`, `read(): object` (never includes secrets), `write(settings)` (partial; `null` removes/resets; secrets go to persistent storage or secret agent), `forget()` (delete profile), `clearSecrets()`, `loaded()`, `settingsChanged(settings)`.

Wired widget snippet:

```qml
Text {
  text: {
    const w = Networking.devices.values.find(d => d.type === DeviceType.Wired);
    if (!w) return "no-eth";
    return w.hasLink ? `eth ${(w as WiredDevice).linkSpeed}Mb/s` : "cable-unplugged";
  }
}
```

Full WiFi applet → §53.

## 50. Bluetooth: adapter (enabled/discovering) + device recipe

- `BluetoothAdapter` (uncreatable): `enabled: bool` (writable — the "powered" switch), `discovering: bool` (writable — the "scanning" switch), `discoverable/pairable: bool` + `discoverableTimeout/pairableTimeout: int` (0 = forever), `devices: ObjectModel<BluetoothDevice>`, `state: BluetoothAdapterState`, `adapterId ("hci0")`, `name`, `dbusPath`.
- `BluetoothDevice`: `name` (writable alias; "" falls back to `deviceName`), `connected: bool` (writable = connect()/disconnect()), `paired/pairing/bonded`, `trusted/blocked/wakeAllowed: bool` (writable), `batteryAvailable/battery (0..1)`, `icon` (via `Quickshell.iconPath()`), `state: BluetoothDeviceState`, `adapter/dbusPath/address`, `connect()/disconnect()/pair()/cancelPair()/forget()`.

```qml
// Card header:
RowLayout {
  Text { text: Bluetooth.defaultAdapter ? (Bluetooth.defaultAdapter.enabled ? "BT on" : "BT off") : "no-adapter" }
  Switch { checked: Bluetooth.defaultAdapter?.enabled ?? false
           onToggled: Bluetooth.defaultAdapter.enabled = checked }
  Button { text: (Bluetooth.defaultAdapter?.discovering ?? false) ? "Stop scan" : "Scan"
           onClicked: Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering }
}
```

Full card with per-device connect/pair + battery → §54. NixOS: `hardware.bluetooth.enable = true`.

## 51. PolkitAgent full (AuthFlow, not onNewRequest)

There is no `onNewRequest` signal. The agent exposes the active flow as properties:

- `PolkitAgent : QtObject`: `isRegistered: bool`, `isActive: bool`, `flow: AuthFlow` (null when idle), `path: string` (default `/org/quickshell/Polkit`).
- `AuthFlow` (uncreatable): `message, inputPrompt, supplementaryMessage/supplementaryIsError, iconName (fdo name → Quickshell.iconPath()), actionId, cookie, identities: list, selectedIdentity` (writable — switching aborts current conversation), `isResponseRequired, responseVisible (false = password), failed (a prior attempt failed), isCompleted/isSuccessful/isCancelled`, `submit(password: string)`, `cancelAuthenticationRequest()`.

```qml
import Quickshell.Services.Polkit
PolkitAgent { id: agent }

PanelWindow {
  visible: agent.isActive
  WlrLayershell.layer: WlrLayer.Overlay
  ColumnLayout {
    Text { text: agent.flow?.message ?? "" }
    Text { text: agent.flow?.supplementaryMessage ?? ""; visible: (agent.flow?.supplementaryMessage ?? "") !== "" }
    TextInput {
      id: pw; echoMode: (agent.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
      onAccepted: agent.flow?.submit(text)
    }
    Text { text: agent.flow?.failed ? "Failed — try again" : ""; visible: agent.flow?.failed ?? false }
    RowLayout {
      Button { text: "Cancel"; onClicked: agent.flow?.cancelAuthenticationRequest() }
      Button { text: "OK"; onClicked: agent.flow?.submit(pw.text) }
    }
    ComboBox {   // multi-identity prompts (user/group picker)
      visible: (agent.flow?.identities.length ?? 0) > 1
      model: agent.flow?.identities ?? []
      onActivated: i => agent.flow.selectedIdentity = agent.flow.identities[i]
    }
  }
}
```

One agent per shell replaces hyprpolkitagent. Trigger test: `pkaction` / anything calling `pkexec`.

## 52. ScreencopyView + ShortcutInhibitor + WlrLayershell + LazyLoader + persistence + easing + WindowManager + FileView details

### ScreencopyView (`Item`, `import Quickshell.Wayland`)

`captureSource: QtObject` (null clears; `ShellScreen` needs wlr-screencopy or ext-image-copy+ext-capture-source; `Toplevel` needs hyprland-toplevel-export-v1), `live: bool` (false = still), `captureFrame()` (no-op when live), `hasContent/sourceSize` (gate visibility on `hasContent`), `paintCursor: bool` (default false), `constraintSize` (nonzero constrains implicit size keeping aspect), `stopped()` (compositor killed the stream — restart may fail).

```qml
ScreencopyView {
  captureSource: Quickshell.screens[0]
  live: true
  paintCursor: true
  visible: hasContent
}
Button { text: "snap"; onClicked: stillView.captureFrame() }
```

### ShortcutInhibitor (`QtObject`)

`window: QtObject` (required, non-null to arm), `enabled: bool` (default false), `active: bool` (readonly — true only when enabled + window focused + compositor grants; compositor can revoke → `cancelled()` and you cannot re-arm programmatically), needs `keyboard-shortcuts-inhibit-v1`.

```qml
ShortcutInhibitor { window: gameOverlay; enabled: gameOverlay.visible }
```

### WlrLayershell (attached on PanelWindow)

`layer: WlrLayer` (default Top), `namespace: string` (CANNOT change after `windowConnected` — set declaratively!), `keyboardFocus: WlrKeyboardFocus` (None/OnDemand/Exclusive). Platform-safe pattern:

```qml
PanelWindow {
  Component.onCompleted: if (this.WlrLayershell != null) this.WlrLayershell.layer = WlrLayer.Bottom;
  WlrLayershell.namespace: "fury-bar"   // hyprctl layers matches "quickshell:<ns>"
}
```

### LazyLoader (`Reloadable`)

`component: Component` (default) xor `source: string`, `active: bool` (sync, blocking, destroys on false), `loading: bool` (async start; no-op if loaded), `activeAsync: bool` (read = loaded; write true = async like `loading`), `item: QtObject` (readonly — touching it mid-load BLOCKS; instead set `loading=true` and wait `onActiveChanged`). Reloads always load synchronously. `Variants` inside `LazyLoader` blocks anyway — don't nest them for perf.

```qml
LazyLoader {
  id: launcherLoader; loading: true   // preload in frame gaps; open via IPC without jank
  Launcher {}
}
// open: launcherLoader.item.visible = true  (first touch may block — that's the documented trade-off)
```

FAQ rule: `Loader` for Item subtrees, `LazyLoader` for non-Item (windows/objects).

### PersistentProperties / Reloadable / Retainable

- `Reloadable`: `reloadableId: string` — stable cross-reload identity. Scoped (Variants branch = scope). `Scope` sets it for all children.
- `PersistentProperties : Reloadable`: declare props inside → values survive reload. `loaded()` (every reload completes) + `reloaded()` (only when an old instance was actually restored).

```qml
PersistentProperties { id: persist; reloadableId: "ui-state"; property bool expanderOpen: false }
```

- `Retainable` (attached): `retained: bool`, `lock()/unlock()/forceUnlock()`, `dropped()` (object would die — lock here to keep for exit transitions), `aboutToDestroy()` (point of no return). Prefer `RetainableLock` over manual lock counting (leaked lock = leak). `NotificationServer.keepOnReload` is the common retainable you already use.

### EasingCurve + ElapsedTimer

- `EasingCurve`: `curve` (same as `PropertyAnimation.easing`), `valueAt(x: real): real`, `interpolate(x, a, b)` overloads for real/point/rect.
- `ElapsedTimer`: `elapsed()/elapsedMs()/elapsedNs()` + `restart()/restartMs()/restartNs()` (restart returns elapsed since last start).

```qml
EasingCurve { id: ease; curve.type: Easing.OutCubic }
ElapsedTimer { id: t }
Button { onClicked: { console.log("gap", t.restartMs(), "ms"); anim.easing = ease.curve } }
```

### WindowManager / Windowset (compositor-agnostic workspaces)

`import Quickshell.WindowManager`. `WindowManager` singleton: `windowsets: list<Windowset>`, `windowsetProjections: list<WindowsetProjection>`, `screenProjection(screen: ShellScreen): ScreenProjection` (per-screen view; same windowset may appear in several). `Windowset`: `id (stable), name, coordinates: list<int>, active/urgent/shouldDisplay (hide pickers when false), projection, canActivate/canDeactivate/canRemove/canSetProjection`, `activate()/deactivate()/remove()/setProjection(p)`.

```qml
Repeater {
  model: WindowManager.windowsets
  delegate: Button { required property var modelData; visible: modelData.shouldDisplay
    text: modelData.name; highlighted: modelData.active
    enabled: modelData.canActivate; onClicked: modelData.activate() }
}
```

### FileView details (supplement to §9)

`path: string` ("" unloads), `adapter: FileViewAdapter` (default property; only `JsonAdapter` today), `preload` (default true), `watchChanges` (+ `onFileChanged: reload()`), `printErrors` (default true), `atomicWrites` (default true — tmp+rename; keep it), `blockLoading/blockAllReads/blockWrites` (all default false — blocking freezes UI; only block pre-window loads, i.e. before root `Component.onCompleted`), `loaded: bool`, `text()/data()` (function-props with `textChanged/dataChanged`), `setText/setData`, `reload()`, `writeAdapter()`, `waitForJob()`, signals `loaded/loadFailed(error: FileViewError)/saved/saveFailed/fileChanged/adapterUpdated`.

```qml
FileView {
  path: Quickshell.statePath("settings.json")
  watchChanges: true; printErrors: true; atomicWrites: true
  onFileChanged: reload()
  JsonAdapter { id: adapter; property string wallpaper: ""; property bool darkMode: true }
}
Button { text: "save"; onClicked: view.writeAdapter() }
```

## 53. Recipe: WiFi applet (scannerEnabled + connectWithPsk dialog)

```qml
// modules/WifiApplet.qml
import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

PanelWindow {
  id: win
  anchors { top: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  implicitWidth: 340; implicitHeight: 480
  visible: false
  WlrLayershell.namespace: "fury-wifi"

  property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
  property var netModel: wifiDevice?.networks ?? null
  property var selected: null   // WifiNetwork awaiting PSK

  onVisibleChanged: if (visible && wifiDevice) wifiDevice.scannerEnabled = true

  ColumnLayout {
    anchors.fill: parent; anchors.margins: 12; spacing: 8
    RowLayout {
      Text { text: wifiDevice ? (wifiDevice.state) : "no wifi"; Layout.fillWidth: true }
      Switch {
        checked: Networking.wifiEnabled
        onToggled: Networking.wifiEnabled = checked   // airplane-mode toggle
      }
    }
    ListView {
      Layout.fillWidth: true; Layout.fillHeight: true; clip: true
      model: win.netModel
      delegate: RowLayout {
        required property var modelData   // WifiNetwork
        width: ListView.view.width
        Text { text: `${modelData.name} ${(modelData.signalStrength*100)|0}%`; Layout.fillWidth: true; elide: Text.ElideRight }
        Text { text: modelData.connected ? "●" : ""; color: "lime" }
        Button {
          text: modelData.connected ? "Drop" : (modelData.known ? "Join" : "Connect")
          onClicked: {
            if (modelData.connected) modelData.disconnect();
            else if (modelData.known) modelData.connect();
            else { win.selected = modelData; pskDialog.open() }
          }
        }
        Connections {
          target: modelData
          function onConnectionFailed(reason) { console.warn("wifi failed", reason) }
        }
      }
    }
  }

  Dialog {
    id: pskDialog; title: "Password for " + (win.selected?.name ?? "")
    standardButtons: Dialog.Ok | Dialog.Cancel
    TextField { id: pskField; echoMode: TextInput.Password; placeholderText: "PSK" }
    onAccepted: win.selected?.connectWithPsk(pskField.text)
  }
}
```

Notes: `scannerEnabled=true` only while open (saves power). Try `connect()` before `connectWithPsk` (backend may have stored secrets → `connectionFailed(NoSecrets)` tells you a PSK is actually needed). Wrong PSK also surfaces as `NoSecrets`. `forget()` on long-press for saved-network management; `NMSettings.read()/write()` for advanced (static IP) editors.

## 54. Recipe: Bluetooth card (adapter + devices + battery)

```qml
import Quickshell.Bluetooth
ColumnLayout {
  property var adapter: Bluetooth.defaultAdapter
  RowLayout {
    Text { text: adapter ? (adapter.name || adapter.adapterId) : "no adapter"; Layout.fillWidth: true }
    Switch { checked: adapter?.enabled ?? false
             onToggled: if (adapter) adapter.enabled = checked }
    Button { text: (adapter?.discovering ?? false) ? "Stop" : "Scan"
             enabled: adapter?.enabled ?? false
             onClicked: adapter.discovering = !adapter.discovering }
  }
  Repeater {
    model: adapter?.devices ?? null
    delegate: RowLayout {
      required property var modelData   // BluetoothDevice
      Image { source: Quickshell.iconPath(modelData.icon, ""); implicitWidth: 22; implicitHeight: 22 }
      ColumnLayout {
        Layout.fillWidth: true
        Text { text: modelData.name || modelData.deviceName; elide: Text.ElideRight }
        Text { text: modelData.batteryAvailable ? `${(modelData.battery*100)|0}%` : modelData.address
               opacity: 0.6; font.pixelSize: 11 }
      }
      Button { text: modelData.connected ? "Drop" : "Join"
               onClicked: modelData.connected ? modelData.disconnect() : modelData.connect() }
      Button { text: modelData.paired ? "Forget" : (modelData.pairing ? "…" : "Pair")
               onClicked: modelData.paired ? modelData.forget() : modelData.pair();
               enabled: !modelData.pairing }
    }
  }
}
```

`trusted=true` for auto-reconnect headsets; `blocked` to ban; `wakeAllowed` for wake-from-suspend mice. Gate the whole card on `Bluetooth.adapters.values.length`.

## 55. Recipe: app-mixer sliders (per-stream volumes + peak meters + default switcher)

```qml
import Quickshell.Services.Pipewire
ColumnLayout {
  // default sink selector
  ComboBox {
    Layout.fillWidth: true
    model: Pipewire.nodes.values.filter(n => n.isSink)
    textRole: "description"
    currentIndex: model.findIndex(n => n === Pipewire.defaultAudioSink)
    onActivated: i => Pipewire.preferredDefaultAudioSink = model[i]  // persisted default!
  }
  // per-stream sliders
  Repeater {
    model: Pipewire.nodes
    delegate: RowLayout {
      required property var modelData   // PwNode
      visible: modelData.isStream && modelData.audio
      Text { text: modelData.nickname || modelData.name; Layout.fillWidth: true; elide: Text.ElideRight }
      Slider {
        value: modelData.audio?.volume ?? 0
        onMoved: if (modelData.audio) modelData.audio.volume = value
      }
      Button { text: (modelData.audio?.muted ?? false) ? "muted" : "mute"
               onClicked: modelData.audio.muted = !modelData.audio.muted }
    }
  }
  // keep bindings alive:
  PwObjectTracker { objects: [...Pipewire.nodes.values.map(n => n.audio)] }
}
// peak meter bar (bind width to peak): PwNodePeakMonitor { node: Pipewire.defaultAudioSink }
```

`audio.volumes` for per-channel; `audio.muted/volume` are writable averages. `PwLinkGroup` for routing UI.

## 56. Recipe: lockscreen end-to-end (WlSessionLock + PamContext)

```qml
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick
import QtQuick.Layouts

WlSessionLock {
  id: lock
  WlSessionLockSurface {
    required property var modelData
    screen: modelData
    color: "black"
    Rectangle {
      anchors.fill: parent
      color: "#0a0a12"
      Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; source: Wallpaper.url; opacity: 0.5 }
      ColumnLayout {
        anchors.centerIn: parent; spacing: 12
        SystemClock { id: clock; precision: SystemClock.Minutes }
        Text { text: Qt.formatDateTime(clock.date, "hh:mm"); font.pixelSize: 72; color: "white" }
        Text { text: pam.message || "Password"; color: pam.messageIsError ? "red" : "#aaa" }
        TextField {
          id: pw; echoMode: pam.responseVisible ? TextInput.Normal : TextInput.Password
          visible: pam.responseRequired
          onAccepted: pam.respond(text)
        }
        Button { text: "Unlock"; onClicked: pam.respond(pw.text) }
      }
    }
  }

  PamContext {
    id: pam
    config: "quickshell-lock"; configDirectory: "/etc/pam.d"; user: Quickshell.env("USER")
    onPamMessage: { pw.text = ""; pw.forceActiveFocus() }
    onCompleted: result => { if (result === PamResult.Success) lock.locked = false }
    onError: e => console.warn("pam", e)
  }

  onLockedChanged: if (locked) { pam.active = true } else { pam.abort?.() }
}
// arm: lock.locked = true (IdleMonitor timeout → lock.locked = true)
// unlock: correct password → completed(Success) → locked=false → compositor releases
// WARNING: killing quickshell while locked leaves the compositor showing solid color (secure, but inoperable).
```

PAM config `/etc/pam.d/quickshell-lock` (`auth sufficient pam_fprintd.so` + `auth required pam_unix.so`); NixOS via `security.pam.services.quickshell-lock`. Pair `WlrLayershell.keyboardFocus: Exclusive` semantics come free with session-lock surfaces.

## 57. Recipe: greeter skeleton (greetd session picker + launch)

```qml
// greeter/shell.qml — runs as the greetd session
import Quickshell
import Quickshell.Services.Greetd
Scope {
  Variants {
    model: Quickshell.screens
    PanelWindow {
      required property var modelData; screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      WlrLayershell.namespace: "greeter"
      ColumnLayout {
        anchors.centerIn: parent
        ComboBox { id: userBox; model: ["fury", "guest"] }
        TextField { id: pwField; echoMode: passEcho ? TextInput.Normal : TextInput.Password }
        property bool passEcho: false
        ComboBox { id: sessBox; model: ["Hyprland", "niri", "sway"];
                   property var cmds: [["Hyprland"], ["niri"], ["sway"]] }
        Button { text: "Login"
          onClicked: { Greetd.createSession(userBox.currentText); pendingCmd = sessBox.cmds[sessBox.currentIndex] } }
        Text { text: statusLine }
      }
    }
  }
  property var pendingCmd: ["Hyprland"]
  property string statusLine: Greetd.available ? ("state: " + Greetd.state) : "NO GREETD SOCKET"
  Connections {
    target: Greetd
    function onAuthMessage(msg, isErr, needResp, echo) {
      statusLine = msg; pwField.echoMode = echo ? TextInput.Normal : TextInput.Password;
    }
    function onAuthFailure(m) { statusLine = "FAIL: " + m; Greetd.createSession(userBox.currentText) }
    function onReadyToLaunch() { Greetd.launch(pendingCmd) }  // quit ASAP after this
  }
  IpcHandler { target: "greeter"; function shutdown(): void { Quickshell.execDetached(["systemctl","poweroff"]) } }
}
```

Test without rebooting: run nested (`cage`/`Hyprland -c` + `Greetd.createSession` against a test socket) or cage the greeter manually.

## 58. GPU / vendor appendix: QtQuick (RHI) on NVIDIA vs AMD/Intel, EGL vs GL, tuning

Quickshell renders QtQuick via the scene graph (RHI; Qt6 default, no legacy direct-GL fallback). Backend selection:

```bash
QSG_RHI_BACKEND=opengl qs -p .     # force OpenGL path (most-tested under Wayland compositors)
QSG_RHI_BACKEND=vulkan qs -p .     # Vulkan path (needs working Vulkan + layers)
QT_QUICK_BACKEND=software qs -p .  # software raster (debug/fallback; slow but vendor-neutral)
QSG_RHI_PREFER_SOFTWARE_RENDERER=1 # allow WARP-style fallback
```

Vendor notes (operational, not API):

- **NVIDIA (proprietary)**: explicit-sync flips caused freezes on 560-series (open kernel module + egl-wayland ~1.1.16). If bars/windows freeze while the compositor runs: `__NV_DISABLE_EXPLICIT_SYNC=1 qs ...` (or compositor-side explicit-sync toggle) is the community workaround. Prefer `wayland-egl` client buffers on NVIDIA (driver ≥364.12 era requirement survives in Qt docs); `QT_WAYLAND_CLIENT_BUFFER_INTEGRATION=wayland-egl` if dmabuf misbehaves. EGLStream history is why `QSG_RHI_BACKEND=opengl` is usually safer than Vulkan on NVIDIA.
- **AMD/Intel (mesa)**: `linux-dmabuf-v1` is the happy path — zero-copy buffers, fractional-scale (`warpSupport`-style paths in mesa) behave. Either RHI backend works; Vulkan is fine if `vulkaninfo` is healthy. Fractional scaling blur → check compositor scale + `QsWindow.devicePixelRatio`, not the shell.
- **Surface tuning (vendor-neutral, real API)**: `QsWindow.surfaceFormat.opaque: false` when a window transitions opaque↔transparent (else it can never become transparent); `updatesEnabled: false` for static windows (wallpapers) to skip re-renders; watch `resourcesLost()` → `closed()` (VRAM exhaustion on resize storms — throttle animations, don't animate everything).
- **Debug**: `qs --help | grep -i debug`, `QSG_INFO=1 qs -p .` (scene-graph backend dump), `QT_LOGGING_RULES="qt.scenegraph.*=true"`, `qs log --follow`. GPU inventory lives in `qs::debuginfo::gpuInfo` (libdrm render nodes) — file it with bug reports.

NixOS tie-in: wrap with `QT_QPA_PLATFORM=wayland`, ship `mesa`/`vulkan-loader` in the wrapper PATH only for helpers (the shell itself inherits the session GL), and keep `QS_DISABLE_CRASH_HANDLER` unset so you get relaunch popups during bring-up.

---

*End of PART VIII — append-only deltas. Core guide above untouched; verify new claims with `qs ipc show`, `qs list --json`, and the v0.3.0 type pages linked per section.*
