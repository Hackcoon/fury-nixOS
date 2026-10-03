# Packaging on NixOS

An exhaustive, independently-usable reference for packaging on NixOS — writing derivations from source, patching existing packages, overlays, flakes with custom packages, build helpers, and debugging builds. Every code block is self-contained and copy-pasteable, with inline comments explaining what each line does.

**Sources synthesized:** nixpkgs contributors guide (stdenv chapters) · Nix Pills (packages 1–9) · nix.dev packaging tutorials · nixpkgs `pkgs/build-support` sources. Conventions verified against nixpkgs release-26.05 (stdenv mkDerivation, `callPackage`, `buildPythonApplication`, `buildGoModule` patterns).

**Companion guides:** `Nix-Language-Deep-Dive.md` (the language machinery used here), your flake (where these outputs land).

---

## Table of Contents

1. [The Mental Model: Derivations](#1-the-mental-model-derivations)
2. [Your First Package (mkDerivation)](#2-your-first-package)
3. [Language Builders (python/go/rust/js/…)](#3-language-builders)
4. [Patching Existing Packages (overrideAttrs)](#4-patching-existing-packages)
5. [Overlays: Local pkgs Augmentation](#5-overlays)
6. [Packages in Your Flake](#6-packages-in-your-flake)
7. [Fetchers: Getting Source In](#7-fetchers)
 8. [Wrappers, PatchELF & Binary Packages](#8-wrappers-patchelf-binary-packages)
     - [8.1 Qt Apps (dontWrapQtApps)](#81-qt-apps-dontwrapqtapps)
 9. [Testing & Debugging Builds](#9-testing-debugging-builds)
     - [9.1 The Debugging Ladder (--print-build-logs, nix develop)](#91-the-debugging-ladder---print-build-logs-nix-develop)
     - [9.2 VM Integration Tests (runNixOSTest)](#92-vm-integration-tests-runnixostest)
     - [9.3 CUDA Packaging (cudaSupport, cudaPackages)](#93-cuda-packaging)
     - [9.4 ROCm Packaging Notes](#94-rocm-packaging-notes)
     - [9.5 Update Scripts, Version Pinning & Hashes](#95-update-scripts-version-pinning-hashes)
     - [9.6 Cross-Compiling Note](#96-cross-compiling-note)
10. [Submitting Upstream (nixpkgs)](#10-submitting-upstream)
     - [10.1 meta.maintainers & longDescription](#101-metamaintainers-longdescription)
11. [Troubleshooting](#11-troubleshooting)
12. [Reference Index](#12-reference-index)

---

## 1. The Mental Model: Derivations

A **derivation** is a pure function: *(source + dependencies + build script) → store path*. Key invariants:

- **No network at build time** except through declared fetchers (§7) — this is the sandbox's whole point.
- **The store path hash** is derived from ALL inputs → same inputs, same path, globally cacheable (`nix-store -r` / cachix share builds).
- **`stdenv.mkDerivation`** is the base builder: a controlled bash environment with every dependency in `PATH`, running `unpack → patch → configure → build → check → install` phases.

```bash
# Any derivation's anatomy, in the shell:
nix derivation show $(which git) | head -30
# → env.src, env.builder, outputs, inputSrcs … the whole recipe
```

## 2. Your First Package

A real C program, start to finish:

```nix
# my-hello.nix — a module file taking the dep-injecting pkgs:
{ stdenv, lib, fetchurl, gnumake }:
#   ↑ callPackage auto-fills each of these from the pkgs set (§5)

stdenv.mkDerivation (finalAttrs: {
  # finalAttrs = self-reference for this derivation — lets later
  # fields (like passthru.tests) refer to finalAttrs.version. Always
  # use this form in new code.

  pname = "my-hello";              # package (repo) name
  version = "1.0.0";                # upstream version

  # ---- Source (§7 for all fetchers) ---------------------------------
  src = fetchurl {
    url = "https://example.com/my-hello-${finalAttrs.version}.tar.gz";
    hash = "sha256-AbCdEf...=";     # WRONG hash on first try is
                                     # NORMAL — nix tells you the right
                                     # one in the error. Paste it back.
  };

  # ---- Build-time dependencies ---------------------------------------
  # nativeBuildInputs: tools RUNNING AT BUILD TIME (compilers, make):
  nativeBuildInputs = [ gnumake ];
  # buildInputs: libraries LINKED/needed at runtime-in-store:
  # buildInputs = [ ];

  # ---- Phases (each overridable; defaults are sane) ------------------
  # configurePhase: runs ./configure if present
  # buildPhase: make
  # installPhase: make install — for simple Makefiles you often must
  #               write it yourself (many Makefiles lack 'install'):
  installPhase = ''
    runHook preInstall              # hook convention: always leave
                                    # pre/post extension points

    mkdir -p $out/bin               # $out = the store path THIS build
                                    # produces; everything ends up in it
    install -m755 my-hello $out/bin/my-hello

    runHook postInstall
  '';

  # ---- Metadata -------------------------------------------------------
  meta = {
    description = "My first packaged program";
    homepage = "https://example.com";
    license = lib.licenses.mit;     # lib.licenses.* — pick from the list
    platforms = lib.platforms.linux;
    mainProgram = "my-hello";       # what ${getExe this-pkg} resolves to
  };
})
```

```bash
# Build & test it — no flake changes needed:
nix-build -E 'let pkgs = import <nixpkgs> {}; in
  pkgs.callPackage ./my-hello.nix {}'
# → ./result/bin/my-hello
```

## 3. Language Builders

Each language has a builder wrapping the repetitive parts:

```nix
# ---- Python (applications, not libraries) ---------------------------
{ buildPythonApplication, fetchPypi, requests }:
buildPythonApplication rec {
  pname = "mytool";
  version = "2.3";
  pyproject = true;               # poetry/pdm/hatch/setuptools-pyproject;
                                  # 'format' is deprecated, use this
  src = fetchPypi {                 # language-specific fetcher:
    inherit pname version;           # knows PyPI URL layout
    hash = "sha256-...";
  };
  dependencies = [ requests ];      # propagated to PYTHONPATH
}

# ---- Go --------------------------------------------------------------
{ buildGoModule, fetchFromGitHub }:
buildGoModule rec {
  pname = "tool";
  version = "0.4.2";
  src = fetchFromGitHub {
    owner = "someone"; repo = pname; rev = "v${version}";
    hash = "sha256-...";
  };
  vendorHash = "sha256-...";        # offline module cache hash —
                                    # set to null FIRST try, read the
                                    # real hash from the error
  # ldflags = [ "-s -w" ];          # strip, shrink binary
}

# ---- Rust ------------------------------------------------------------
{ rustPlatform, fetchFromGitHub }:
rustPlatform.buildRustPackage rec {
  pname = "tool"; version = "1.2";
  src = fetchFromGitHub {
    owner = "s"; repo = pname; rev = version; hash = "sha256-...";
  };
  cargoHash = "sha256-...";         # cargo lock hash — same null-first trick
  # nativeBuildInputs = [ pkg-config ];
  # buildInputs = [ openssl ];
}

# ---- Node / JS --------------------------------------------------------
{ buildNpmPackage, fetchFromGitHub }:
buildNpmPackage rec {
  pname = "webapp"; version = "3.1";
  src = fetchFromGitHub {
    owner = "o"; repo = pname; rev = "v${version}"; hash = "sha256-...";
  };
  npmDepsHash = "sha256-...";       # package-lock hash
  # npmBuildScript = "build";       # defaults to "build"
}
```

Builder table: `buildRustPackage` · `buildGoModule` · `buildPythonApplication`/`...Package` (libraries) · `buildNpmPackage`/`buildYarnPackage` · `buildGradle` · `buildMaven` · `buildPerl`, `buildPerlPackage` · `stdenv.mkDerivation` (everything else, incl. prebuilt binaries §8).

## 4. Patching Existing Packages

The single most-used packaging skill — modify an nixpkgs package without forking it:

```nix
{ pkgs, lib }: {
  # ---- overrideAttrs: change fields of ONE derivation ----------------
  my-hello-patched = pkgs.hello.overrideAttrs (old: {
    # 'old' = the original attrset. Spread what you keep, replace what
    # you need. EVERYTHING not mentioned stays identical:

    # 1. Add a patch file (relative to THIS nix file):
    patches = (old.patches or [ ]) ++ [ ./hello-nicer-output.patch ];

    # 2. Change configure flags:
    # configureFlags = (old.configureFlags or []) ++ [ "--with-extras" ];

    # 3. Change a version + source in one move:
    # version = "2.12.1";
    # src = pkgs.fetchurl {
    #   url = "mirror://gnu/hello/hello-2.12.1.tar.gz";
    #   hash = "sha256-...";
    # };

    # 4. Environment tweaks:
    # env.CFLAGS = "-O3";
  });
}
```

```nix
# ---- .override: change the ARGUMENTS to the package's function ------
# Packages are callPackage'd FUNCTIONS with named args; .override
# re-calls with different args:
pkgs.hello.override {
  # if hello's .nix took { enableNls ? true }:
  enableNls = false;
}
# Real-world classics:
pkgs.firefox.override {              # native messaging host:
  extraNativeMessagingHosts = [ pkgs.passff-host ];
}
pkgs.steam.override {               # gaming guide's MANGOHUD injection:
  extraEnv = { MANGOHUD = true; };
}
# .override (args) vs .overrideAttrs (final derivation attrs):
#   args affect WHAT the recipe gets; attrs affect the recipe output.
```

## 5. Overlays

Your local package universe, applied to the global `pkgs`:

```nix
# overlays/default.nix — the overlay itself (final/prev §Deep-Dive §8):
final: prev: {
  # your packaged tool, auto-wired deps:
  my-hello = final.callPackage ../pkgs/my-hello.nix { };

  # patched existing package:
  hello = prev.hello.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../patches/hello-fix.patch ];
  });
}
```

```nix
# Wiring into the flake (Nix-Language-Deep-Dive.md §8-9 pattern):
{
  nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
    modules = [
      ({ ... }: {
        nixpkgs.overlays = [ (import ./overlays/default.nix) ];
      })
      ./configuration.nix
    ];
  };
}
```

After rebuild: `pkgs.my-hello` is just another package — usable in `environment.systemPackages`, `programs.*.package`, everywhere.

## 6. Packages in Your Flake

```nix
# flake.nix — expose your packages per-system:
{
  outputs = { self, nixpkgs }: let
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ];
  in {
    packages = forAllSystems (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        my-hello = pkgs.callPackage ./pkgs/my-hello.nix { };
        # default = self.packages.${system}.my-hello;  # nix build .# shortcut
      });

    # A dev shell for hacking on it (§9):
    devShells = forAllSystems (system:
      let pkgs = nixpkgs.legacyPackages.${system}; in {
        default = pkgs.mkShell {
          packages = [ pkgs.gnumake ];
          shellHook = ''echo "my-hello dev env"'';
        };
      });
  };
}
```

```bash
nix build .#my-hello        # builds into ./result
nix run .#my-hello          # build AND run — no install needed
nix shell .#my-hello        # enter an env with it on PATH
```

## 7. Fetchers

Getting source into the sandbox — **the only sanctioned network**:

```nix
{ fetchurl, fetchzip, fetchFromGitHub, fetchgit, fetchPypi, ... }: {

  # Plain URL (tarball preferred):
  fetchurl { url = "https://.../x.tar.gz"; hash = "sha256-..."; }

  # Needs unpacking to a directory tree (GitHub zip archives!):
  fetchzip { url = "https://.../x.zip"; hash = "sha256-..."; }

  # GitHub/GitLab shorthand (releases, tags, commits):
  fetchFromGitHub {
    owner = "gnif"; repo = "LookingGlass";
    rev = "B7";                     # anything sha-addressable
    hash = "sha256-...";
    fetchSubmodules = true;         # --recurse-submodules
  }

  # Raw git (branch heads work, but are MOVING — pin commits!):
  fetchgit {
    url = "https://git.example/repo";
    rev = "abc123...";
    hash = "sha256-...";
    # branchName = "main";          # only as documentation
  }

  # Hash rule of thumb: put a dummy "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  # — the build FAILS and prints the correct hash. Copy it back. That
  # failure message is the canonical workflow, not an error condition.
}
```

## 8. Wrappers, PatchELF & Binary Packages

For closed-source/prebuilt blobs (the Looking-Glass/Bottles world):

```nix
{ stdenv, fetchurl, autoPatchelfHook, alsa-lib, ... }:
stdenv.mkDerivation rec {
  pname = "vendor-tool"; version = "1.0";
  src = fetchurl {
    url = "https://vendor.example/tool-${version}.tar.gz";
    hash = "sha256-...";
  };

  # autoPatchelfHook: at fixup time, rewrite the binary's RPATH to point
  # at store paths of everything in buildInputs — the "it just works"
  # for vendor ELF binaries:
  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ alsa-lib ];       # libs the binary needs at runtime

  # Binary packages usually have no build — skip straight to install:
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share
    cp -r * $out/share/
    ln -s $out/share/tool $out/bin/tool
    runHook postInstall
  '';

  # If the binary hardcodes /usr paths:
  # postFixup = ''
  #   substituteInPlace $out/bin/launcher \
  #     --replace /usr/share $out/share
  # '';
}
```

**steam-run for unbuildable things:** when packaging is truly not worth it — `steam-run ./binary` gives any binary the FHS illusion (see Gaming guide).

### 8.1 Qt Apps (dontWrapQtApps)

```nix
# ---- Qt6 (Qt5: libsForQt5.callPackage + qtbase/wrapQtAppsHook) -----
{ stdenv, lib, qt6, cmake }:
stdenv.mkDerivation {
  pname = "myapp"; version = "1.0";
  # ... src etc. ...
  buildInputs = [ qt6.qtbase ];              # Qt libs LINKED at runtime
  nativeBuildInputs = [ cmake qt6.wrapQtAppsHook ];  # the wrapper hook
  # qtWrapperArgs = [ "--prefix PATH : ${lib.makeBinPath [ ... ]}" ];
  #   ↑ extra runtime deps (helpers the app shells out to) — passed
  #   through to wrapProgram. Also visible as $qtWrapperArgs in fixup.
}
# Rule: EVERY Qt package has wrapQtAppsHook in nativeBuildInputs,
# OR explicitly sets dontWrapQtApps. The hook injects QT_PLUGIN_PATH /
# QML2_IMPORT_PATH / XDG_DATA_DIRS so plugins resolve from the store.
```

```nix
# ---- Manual wrapping (multi-binary, scripts, PyQt) ------------------
{ stdenv, qt6 }:
stdenv.mkDerivation {
  pname = "myapp"; version = "1.0";
  # ... src ...
  nativeBuildInputs = [ qt6.wrapQtAppsHook ];
  dontWrapQtApps = true;      # disable AUTO-wrapping; you wrap by hand
  preFixup = ''
    # wrapQtApp = small wrapper over wrapProgram preloaded with Qt args:
    wrapQtApp "$out/bin/myapp" --prefix PATH : /path/to/helpers
    # wrapQtApp "$out/bin/myapp-cli" --prefix PATH : /path/to/helpers
  '';
}
# When to go manual: package ships several binaries but only some are
# Qt apps; app is a non-ELF script (hook IGNORES scripts — PyQt/Python
# launchers always need manual wrapQtApp); you need per-binary flags.
# Symptom of missing wrap: `could not find the Qt platform plugin "xcb"`.
```

## 9. Testing & Debugging Builds

### 9.1 The Debugging Ladder (--print-build-logs, nix develop)

```bash
# The escalating debugging ladder — use the CHEAPEST that answers you:

# 1. Just build (sandbox, clean env):
nix-build -E '... callPackage ./my-hello.nix {}'

# 1b. Flake equivalent — STREAM the log live (default buffers it):
nix build .#my-hello --print-build-logs   # -L shorthand; repeat -L for more
# nix build .#my-hello --print-build-logs --keep-failed  # + keep /tmp dir

# 2. Build & keep the shell where it failed:
nix-build ... --keep-failed          # cd into /tmp/nix-build-*/ and look

# 3. Interactive-ish: break at a phase:
#    add to the derivation:  installPhase = "false";  etc. to bisect

# 4. Full sandbox escape for real debugging (enter the build env):
nix-shell -E '... callPackage ./my-hello.nix {}'
# → you're in the BUILD environment with all deps on PATH; run the
#   phases manually: unpackPhase; cd my-hello-*; configurePhase; buildPhase

# 4b. Flakes: nix develop = your devShells.default (§6) as an env:
nix develop                  # drops you in mkShell with gnumake etc.
nix develop -c bash -c 'make && ./my-hello'  # non-interactive variant
# nix develop --ignore-environment  # closest to the pure build env

# 5. Raw derivation inspection:
nix derivation show ./result
nix log show ./result               # full build log post-hoc (binary cache)
nix log --print-build-logs .#my-hello  # force local build log path
```

```nix
# In-derivation debugging hooks (temporary, remove before merging):
# preBuild = ''
#   set -x                            # echo every command
#   ls -la
# '';
# And the ultimate: break the build on purpose with `false` between
# phases to walk through interactively in the kept temp dir.
```

### 9.2 VM Integration Tests (runNixOSTest)

```nix
# pkgs/my-hello.nix — attach a VM test that boots NixOS WITH your pkg:
{ stdenv, lib, fetchurl, gnumake, runNixOSTest }:
stdenv.mkDerivation (finalAttrs: {
  pname = "my-hello"; version = "1.0.0";
  # ... src/build/install as in §2 ...
  passthru.tests.vm = runNixOSTest {
    name = "my-hello-smoke";
    nodes.machine = { pkgs, ... }: {
      environment.systemPackages = [ finalAttrs.finalPackage ];
    };
    # testScript: python harness driving the VM over its serial console:
    testScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("my-hello | grep -q hello")
    '';
  };
})
```

```bash
nix build .#my-hello.passthru.tests.vm   # runs the VM test headlessly
# In nixpkgs checkouts: nix-build nixos/tests/my-hello.nix
# See nixpkgs nixos/tests/ for the runNixOSTest harness (multi-node,
# networking, snapshots — same API your package test uses).
```

### 9.3 CUDA Packaging

```nix
# ---- Optional CUDA support (the nixpkgs convention) -----------------
{ lib, stdenv, config
, cudaSupport ? config.cudaSupport   # ← THE flag: off by default
, cudaPackages                       # ← redistributables set (NOT legacy
                                     #   cudatoolkit — see note below)
}:
stdenv.mkDerivation {
  pname = "mytool"; version = "1.0";
  # ... src ...
  buildInputs = lib.optionals cudaSupport (with cudaPackages; [
    cuda_cudart        # runtime — link ONLY what you use (closure size!)
    libcublas
    # cudnn  # only ML inference/training tools; heavy, keep optional
  ]);
  cmakeFlags = lib.optionals cudaSupport [
    "-DWITH_CUDA=ON"
    "-DCMAKE_CUDA_ARCHITECTURES=native"  # or explicit "75;80;86"
  ];
  # Never hard-require CUDA: gate behind cudaSupport so Hydra builds the
  # CPU path and CUDA users get the GPU path via config or pkgsCuda.
}
```

```nix
# ---- Enabling it as a USER (no packaging change needed) ------------
# nixpkgs-wide (rebuilds the world — import nixpkgs ONCE with it):
#   pkgs = import nixpkgs { config.cudaSupport = true;
#     config.cudaCapabilities = [ "8.6" "8.9" ];  # YOUR arch (sm_86=Ampere,
#     # sm_89=Ada, sm_90=Hopper) — check nvidia-smi --query-gpu=compute_cap
#     config.allowUnfreePredicate = pkg: builtins.elem pkg.pname [ "cuda_cudart" "libcublas" ];
#   };
# Per-package (cheap — only this package rebuilds):
#   mytool-cuda = pkgs.mytool.override { cudaSupport = true; };
# Prebuilt variant: pkgs.pkgsCuda.mytool (nixpkgs preconfigured with
# cudaSupport=true), or pkgs.pkgsForCudaArch.sm_89.mytool for one arch.
# Prefer cudaPackages.cuda_cudart/libcublas over legacy cudaPackages.cudatoolkit
# (monolithic runfile symlinkJoin — deprecated, huge closure; new code uses
# the fine-grained redistributables). cudaCapabilities + cudaForwardCompat
# control PTX/JIT forward-compat; allowUnfree covers the CUDA EULA.
# Intel/AMD GPU here? You want §9.4 (ROCm) or OpenCL/Vulkan-compute, NOT CUDA.
```

### 9.4 ROCm Packaging Notes

```nix
# ---- Optional ROCm support (AMD GPUs, mirror of CUDA pattern) -------
{ lib, stdenv, config
, rocmSupport ? config.rocmSupport
, rocmPackages
}:
stdenv.mkDerivation {
  pname = "mytool"; version = "1.0";
  # ... src ...
  buildInputs = lib.optionals rocmSupport (with rocmPackages; [
    clr              # runtime (replaces legacy rocm-runtime/opencl)
    rocblas
    # miopen-hip  # ML only, heavy
  ]);
  cmakeFlags = lib.optionals rocmSupport [
    "-DWITH_ROCM=ON"
    "-DHIP_HIPCC=${rocmPackages.clr}/bin/hipcc"
    "-DGPU_TARGETS=gfx1030;gfx1100"  # YOUR gfx arch — rocminfo reports it
  ];
}
# Enable: config.rocmSupport = true (nixpkgs-wide) or
#   .override { rocmSupport = true; }. ROCm supports FEWER GPUs than
# CUDA (CDNA/RDNA focus; Vega/Polaris often unsupported upstream), needs
# a matching kernel (amdgpu in-tree, recent linuxPackages), and CPU+GPU
# arch combos matter more — gate behind the flag, document tested gfx
# targets in longDescription (§10.1). NVIDIA GPU? You want §9.3, not this.
```

### 9.5 Update Scripts, Version Pinning & Hashes

```nix
# ---- Automated updates (nixpkgs convention) -------------------------
{ lib, stdenv, fetchFromGitHub, nix-update-script, gitUpdater }:
stdenv.mkDerivation (finalAttrs: {
  pname = "mytool"; version = "1.2.3";   # ← PINNED, never "latest"/branch
  src = fetchFromGitHub {                # rev pinned to the version tag:
    owner = "someone"; repo = "mytool"; rev = "v${finalAttrs.version}";
    hash = "sha256-...";                 # pinned alongside (§7 dummy-hash trick)
  };
  passthru.updateScript =
    nix-update-script { };               # `nix-shell maintainers/scripts/update.nix --argstr package mytool`
    # Alternatives: gitUpdater { rev-prefix = "v"; } for simple tags;
    # custom shell script for odd version schemes.
})
```

```bash
# Version bump workflow (pin + hash, the disciplined loop):
# 1. Bump version = in the .nix, update rev to the new tag.
nix-update mytool --version=1.2.4     # rewrites version+hash automatically
# 2. No nix-update? Prefetch the hash yourself:
nix hash from-sri --type sha256 --expr \
  '(builtins.getFlake "nixpkgs").packages.x86_64-linux.mytool.src'
# or legacy: nix-prefetch-url --type sha256 <tarball-url>
# or: set hash = "sha256-AAAA...=" once, build, paste the `got:` hash.
# 3. Go/Rust/JS lock hashes (vendorHash/cargoHash/npmDepsHash §3) change
#    on EVERY version bump — null-first trick again, then build.
# Rule: version + src hash + lock hashes move TOGETHER in one commit
# (`mytool: 1.2.3 -> 1.2.4`), CI verifies the build. Unpinned branches/
# `rev = "main"` are rejectable upstream — not reproducible.
```

### 9.6 Cross-Compiling Note

```nix
# ---- Cross note (aarch64 binary from your x86_64 host) --------------
# Most well-behaved mkDerivation packages cross with zero changes —
# the bugs live in nativeBuildInputs vs buildInputs confusion:
#   nativeBuildInputs: runs ON THE BUILD machine (compilers, codegen,
#     protoc, pkg-config) — NEVER libraries you link.
#   buildInputs: runs/links ON THE HOST (target) machine (openssl, qtbase).
#   depsBuildTarget: tools the TARGET runs at build time (rare, emulators).
{
  outputs = { self, nixpkgs }: let
    pkgsX86 = nixpkgs.legacyPackages.x86_64-linux;
    # pkgsCross: every package recompiled FOR aarch64:
    pkgsAarch64 = pkgsX86.pkgsCross.aarch64-multiplatform;
  in {
    packages.x86_64-linux.my-hello-aarch64 =
      pkgsAarch64.callPackage ./pkgs/my-hello.nix { };
  };
}
```

```bash
nix build .#my-hello-aarch64          # ELF aarch64 binary on x86_64 host
# file ./result/bin/my-hello          # → ARM aarch64, verify it
# Fails with "cannot run test program while cross compiling"? Upstream
# configure tried to EXECUTE target code — patch with --host flags or
# depsBuildTarget emulator (qemu). CUDA/ROCm do NOT cross (GPU toolkits
# are arch+driver-locked); Qt needs target qtbase, host wrapQtAppsHook.
```

## 10. Submitting Upstream

Your overlay works → share it:

1. Package under `pkgs/by-name/<first-two-letters>/<pname>/package.nix` (the modern layout).
2. Add to `pkgs/README.md` conventions: `finalAttrs:` form, `hash` not `sha256`, `lib.licenses`, `meta.mainProgram`.
3. Test: `nix-build -A pkgname` from a nixpkgs checkout; `nixpkgs-review pr <number>` for reviewing others.
 4. `nixfmt-tree` (the repo's formatter — CI enforces it).
 5. PR checklist: `meta` complete (§10.1), no `version` in pname, hashes pinned, commit style `pkgname: init at version`.

### 10.1 meta.maintainers & longDescription

```nix
{ lib, ... }:
stdenv.mkDerivation {
  # ... pname/version/src/build ...
  meta = {
    description = "One-line summary (no trailing period, no 'A tool for')";
    longDescription = ''
      Two-to-three sentences: what it does, who it's for, notable
      backends (CUDA §9.3 / ROCm §9.4 / CPU-only) and GPU vendor
      caveats. Shows on search.nixos.org — write for strangers.
    '';
    homepage = "https://example.com";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "my-hello";
    maintainers = with lib.maintainers; [ yourhandle ];  # ← ADD YOURSELF
    # maintainers = you opting into `nixpkgs-review` pings + update-script
    # failures. No maintainer = orphan = slow merges. Find handles in
    # nixpkgs maintainers/maintainer-list.nix.
  };
}
```

## 11. Troubleshooting

| Symptom | Fix |
|---|---|
| `hash mismatch` on first build | Expected workflow — copy the `got:` hash from the error into `hash =`. |
| `no install target` / nothing in `$out` | Makefile lacks install; write `installPhase` (§2). |
| Binary can't find `.so` at runtime | RPATH missing — `autoPatchelfHook` + proper `buildInputs` (§8), or check `ldd ./result/bin/x`. |
| `SSL certificate problem` during build | Sandbox network is fetchers-only; your build step tried to download → prefetch into `src` or a fetcher output. |
| Python `could not find module` at runtime | Missing from `dependencies` (not just nativeBuildInputs) — propagated Python deps must be in the set the builder propagates. |
| `vendorHash`/`cargoHash` mismatch loop | Set to `null` once, read real hash from error, paste. If it keeps changing: unclean workspace — `nix clean` / flake check. |
| Patch fails to apply | Upstream file drifted — regenerate with `diff -u`, and match the `-p1` strip level (patches apply from `$NIX_BUILD_TOP`. |
| Works in `nix-shell`, fails in build | Shell env pollution (your dotfiles set vars). True builds have a controlled env — reproduce with `nix-shell --pure`. |
| Qt app double-wrapped / broken env | Upstream already wraps via `wrapQtAppsHook` — set `dontWrapQtApps = true;` only when you wrap manually with `wrapQtApp`. |

## 12. Reference Index

- nixpkgs stdenv docs: <https://nixos.org/manual/nixpkgs/stable/#part-stdenv>
- Nix Pills packaging chapters: <https://nixos.org/guides/nix-pills/>
- Language builders: `nixos/../pkgs/build-support/` sources
- nix.dev packaging tutorials: <https://nix.dev/tutorials/>
- Contributing guide: `nixpkgs/CONTRIBUTING.md` + `pkgs/README.md`
 - `nixpkgs-review`: <https://github.com/Mic92/nixpkgs-review>
 - nixfmt: <https://github.com/nix-community/nixfmt>
 - CUDA packaging: nixpkgs `doc/languages-frameworks/cuda.section.md` + `pkgs/top-level/cuda-packages.nix`
 - ROCm packaging: nixpkgs ROCm docs (`doc/languages-frameworks/rocm.section.md`), `rocmPackages` set
 - nix-update: <https://github.com/Mic92/nix-update> (`passthru.updateScript`, `nix hash from-sri`)
 - Cross-compilation: Nixpkgs manual "Cross Compilation" chapter, `pkgsCross.*` sets
- Companions: `Nix-Language-Deep-Dive.md` (language), your flake (`Packaging §6` pattern lands in its outputs)
