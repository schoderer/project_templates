#!/usr/bin/env bash
# Lists the GPUs ROCm sees (runs inside the container via `just gpu-info`).
set -euo pipefail

echo "GPUs (put the UUID of the card to use into .env as ROCR_VISIBLE_DEVICES):"
rocminfo | awk '
  function flush() {
    if (type == "GPU") printf "  %-32s %-8s %s\n", name, arch, uuid
    type = ""; name = ""; arch = ""; uuid = ""
  }
  /^Agent [0-9]+/      { flush() }
  /^  Name:/           { arch = $2 }
  /^  Uuid:/           { uuid = $2 }
  /^  Device Type:/    { type = $3 }
  /^  Marketing Name:/ { sub(/^  Marketing Name: +/, ""); name = $0 }
  END                  { flush() }
'
echo

if command -v amd-smi >/dev/null; then
  amd-smi monitor
else
  rocm-smi
fi
