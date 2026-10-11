#!/usr/bin/env bash
count=1
[[ "${1:-}" == "-n" && "${2:-}" =~ ^[0-9]+$ ]] && count="$2"
python3 -c "import uuid; [print(uuid.uuid4()) for _ in range($count)]"