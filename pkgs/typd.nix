# ============================================================
# TYPED (typd) — floating/draggable/resizable Wayland virtual keyboard
# ============================================================
# Upstream: https://github.com/revanthlol/typd (Rust, cargo build)
# Why this instead of wvkbd/Onboard:
#   - wvkbd = bottom dock only, can't move/resize.
#   - Onboard (XWayland window) can't work on Hyprland: clicking it
#     steals keyboard focus (Hyprland ignores WM_HINTS input=False),
#     and Hyprland's `nofocus` rule kills pointer clicks too. Dead end.
#   - typd = layer-shell surface (like wvkbd, never takes focus, clicks
#     always work) PLUS drag-bar to move anywhere + resize edges/corners.
#     Keys go out via zwp_virtual_keyboard_v1 (same as wvkbd) so typing
#     lands in the focused app. Verified in source: exclusive_zone=-1
#     (floats over content), no keyboard interactivity requested.
#
# HOW TO UPDATE (rev + hash + Cargo.lock move together):
#   1. Pick a commit (repo has no tags; main is tiny, check
#      https://github.com/revanthlol/typd/commits/main/).
#   2. Set `rev` below to the full 40-char hash.
#   3. Set `hash` to the placeholder
#      "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=".
#   4. Copy the new Cargo.lock next to this file:
#      nix shell nixpkgs#nix-prefetch-git --command \
#        nix-prefetch-git https://github.com/revanthlol/typd --rev <REV>
#      cp <store-path>/Cargo.lock /etc/nixos/pkgs/typd-Cargo.lock
#      (get <store-path> from the prefetch output's "path is ..." line)
#   5. Run: sudo nixos-rebuild build --flake /etc/nixos#nixos
#      Nix fails on purpose printing "got: sha256-REALHASH..." — paste it
#      into `hash`, rebuild again. Done.
#
# The function arguments below are auto-injected by callPackage from
# configuration.nix — never passed manually.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  cairo,
  libxkbcommon,
  wayland,
}:

rustPlatform.buildRustPackage {
  pname = "typd";
  version = "0.1.0-unstable-2026-05-03";

  src = fetchFromGitHub {
    owner = "revanthlol";
    repo = "typd";
    rev = "6625c102ef792a24071323a42ea66e6e314998cd";
    hash = "sha256-WBm6C35wOIlAaTt7NTqoJXVfG70z/6u5UzBdqVFhbEg=";
  };

  # Cargo.lock is NOT referenced from $src (it must exist at eval time),
  # so it lives next to this file — keep in sync with `rev` (see above).
  cargoLock = {
    lockFile = ./typd-Cargo.lock;
  };

  # Local patches (rebase on update if upstream moves):
  # - typd-drag.patch: skip full Cairo redraw on every drag-motion event.
  #   The key layout doesn't change while moving — the compositor
  #   repositions the existing buffer. Without this, drags lag badly
  #   (full 1280x480 software redraw per motion event).
  patches = [ ./typd-drag.patch ];

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    cairo # renderer.rs draws the keys with Cairo
    libxkbcommon # keymap upload for the virtual keyboard protocol
    wayland # wayland-sys links the system client lib
  ];

  # No tests upstream (src/ has no `cargo test` targets).
  doCheck = false;

  meta = with lib; {
    description = "Floating, draggable, resizable Wayland virtual keyboard (mouse-usable)";
    homepage = "https://github.com/revanthlol/typd";
    # NOTE: upstream declares no license (no LICENSE file, no
    # Cargo.toml license field as of 2026-05-03) — revisit on update.
    # `license` deliberately omitted rather than guessed.
    maintainers = [ ];
    platforms = platforms.linux;
    mainProgram = "typd";
  };
}
