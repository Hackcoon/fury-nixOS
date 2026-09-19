# ============================================================
# OPENWOLF — custom package built from upstream source with pnpm
# ============================================================
# Upstream: https://github.com/cytostack/openwolf
# Upstream is a Node.js CLI (`npm install -g openwolf`). The published
# npm tarball does NOT bundle its dependencies (commander, express…),
# so wrapping the tarball alone leaves `openwolf` broken
# ("Cannot find package 'commander'"). Instead we build from source:
#
#   fetchFromGitHub → pinned source, verified against `hash`
#   fetchPnpmDeps   → pinned dependency store, verified against its
#                     own `hash` (works OFFLINE inside the sandbox)
#   pnpm build      → tsc + hooks + dashboard (upstream's build script)
#   pnpm install    → self-contained $out with PROD deps only
#   makeWrapper     → $out/bin/openwolf runs node on dist/bin/openwolf.js
#
# NOTE: use the TOP-LEVEL fetchPnpmDeps/pnpmConfigHook (not
# pnpm_10.fetchDeps / pnpm_10.configHook — those package attributes are
# deprecated and print evaluation warnings). The pnpm VERSION is still
# pinned explicitly via `pnpm = pnpm_10` below: lockfile is v9.0 and
# pnpm_9 is flagged insecure in nixpkgs, so pnpm_10 it is.
#
# The function arguments below are auto-injected by callPackage from
# configuration.nix — never passed manually.
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_10,
  nodejs,
  makeWrapper,
}:

stdenv.mkDerivation (finalAttrs: {
  # ----------------------------------------------------------
  # HOW TO UPDATE (version + 2 hashes move together):
  # ----------------------------------------------------------
  # 1. Check https://github.com/cytostack/openwolf/releases/latest
  #    Note the tag, e.g. v2.6.0.
  # 2. Change `version` below to "2.6.0" (WITHOUT the leading v —
  #    the `rev` line adds it back).
  # 3. Reset BOTH hashes to the placeholder
  #      "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  #    (`hash` for source, `pnpmDeps.hash` for dependencies).
  # 4. Run: sudo nixos-rebuild build --flake /etc/nixos#nixos
  #    Nix fails TWICE on purpose (once per hash), each time printing:
  #      specified: sha256-AAAA...
  #      got:       sha256-REALHASH...
  #    Paste each "got:" value into its hash, rebuild after each one.
  #    (Do `hash` first, then pnpmDeps `hash` — the second error only
  #    appears once the first hash is correct.)
  # 5. Test, then switch:
  #      sudo git -C /etc/nixos add pkgs/openwolf.nix
  #      nix-test          # trial activation (your alias)
  #      openwolf --version && openwolf status
  #      nix-switch        # permanent
  #
  # If upstream adds/removes dependencies, pnpmDeps `hash` changes even
  # when `version` doesn't — same dance, placeholder + paste "got:".
  # ----------------------------------------------------------

  # Package name — becomes $out/bin/openwolf.
  pname = "openwolf";

  # >>> CHANGE THIS on update (release version, no leading v). <<<
  version = "2.5.2";

  # Pinned source. Tag is v<VERSION> upstream (e.g. v2.5.2).
  src = fetchFromGitHub {
    owner = "cytostack";
    repo = "openwolf";
    rev = "v${finalAttrs.version}";
    # >>> PASTE THE REAL HASH HERE after the first failed build. <<<
    hash = "sha256-bwAd4UowuVzO1Fr5Ec9gmn5/LCitueUJzZtApVmoEdI=";
  };

  # Pinned pnpm dependency store (from pnpm-lock.yaml at the rev above).
  # Built OFFLINE — no network inside the sandbox past this fetch.
  # `pnpm = pnpm_10`: lockfile is v9.0, readable by pnpm 10. (pnpm_9
  # exists but nixpkgs flags that exact version insecure — and it's
  # build-time-only anyway, never installed. Default pnpm is v11;
  # untested against this lockfile, so stay on 10 until upstream moves.)
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    # >>> PASTE THE REAL HASH HERE after the second failed build. <<<
    hash = "sha256-CIt0RkSTZVakIZW5AoOtDGsCe6jgjJJi33+zv+A8MCI=";
  };

  nativeBuildInputs = [
    nodejs # Node 24 on stable — upstream needs >= 20 (package.json engines)
    pnpmConfigHook # wires `pnpm install` to the pinned store, offline
    pnpm_10 # the actual pnpm binary for build/install below
    makeWrapper
  ];

  # Upstream build = tsc && checks && hooks && dashboard (package.json).
  # All devDeps (typescript, vite…) come from the pinned store above.
  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    # Copy what `npm publish` would ship (package.json `files`: dist/,
    # templates, docs) plus package.json + lockfile (lockfile is only
    # used for the install below, then deleted).
    mkdir -p $out/lib/openwolf
    cp -r dist src/templates docs package.json pnpm-lock.yaml \
      LICENSE README.md CREDITS.md CHANGELOG.md $out/lib/openwolf/

    # Install PRODUCTION deps only, offline from the pinned store.
    # (DevDeps like typescript/vite were needed for the build above
    # but must not bloat the installed closure.)
    cd $out/lib/openwolf
    pnpm install --prod --offline --frozen-lockfile --ignore-scripts
    rm $out/lib/openwolf/pnpm-lock.yaml

    # $out/bin/openwolf → `node $out/lib/openwolf/dist/bin/openwolf.js`
    # (upstream package.json `bin` points at dist/bin/openwolf.js).
    # If upstream renames that entry point, the wrapper builds fine but
    # running `openwolf` errors "no such file" — check package.json
    # `bin` on GitHub and update the path after --add-flags.
    mkdir -p $out/bin
    makeWrapper ${lib.getExe nodejs} $out/bin/openwolf \
      --add-flags "$out/lib/openwolf/dist/bin/openwolf.js"
    runHook postInstall
  '';

  meta = {
    description = "Local project memory, context tools and recorded token usage for coding agents";
    homepage = "https://github.com/cytostack/openwolf";
    downloadPage = "https://github.com/cytostack/openwolf/releases";
    license = lib.licenses.agpl3Only;
    mainProgram = "openwolf";
    platforms = [ "x86_64-linux" ];
  };
})
