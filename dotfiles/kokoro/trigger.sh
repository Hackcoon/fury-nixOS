#!/usr/bin/env bash
# Minimal trigger.sh shim for NixOS (upstream never committed one).
# dusky_main.py carries every client command (speak/stop/pause/status/
# doctor/voices/reload/unload/shutdown) on stdlib only — this just execs it.
# Installed by kokoro_installer.sh to $TRIGGER_DIR and symlinked as
# ~/.local/bin/dusky-kokoro. Requires CPython 3.14+ (PEP 758 syntax).
set -euo pipefail
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MAIN="$HERE/dusky_main.py"
if [[ ! -f "$MAIN" ]]; then
    MAIN="$HOME/contained_apps/uv/dusky_kokoro/dusky_main.py"
fi
# Prefer the venv interpreter (has onnxruntime/kokoro for daemon/doctor/
# synth); pure socket clients work on any 3.14+. NixOS needs the driver
# libs first in LD_LIBRARY_PATH (libcuda) — nix-ld dir covers libstdc++.
VENV_PY="$HOME/contained_apps/uv/dusky_kokoro/.venv/bin/python"
if [[ -x "$VENV_PY" ]]; then
    PY="$VENV_PY"
else
    PY="python3.14"
fi
export LD_LIBRARY_PATH="/run/current-system/sw/share/nix-ld/lib:/run/opengl-driver/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$PY" "$MAIN" "$@"
