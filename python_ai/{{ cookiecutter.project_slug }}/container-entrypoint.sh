#!/usr/bin/env bash
# Syncs the project venv against the image's python and runs the given command in it.
set -euo pipefail

venv="${UV_PROJECT_ENVIRONMENT:?}"
image_python="$(command -v python3)"

uv venv --quiet --allow-existing --python "$image_python" "$venv"

# Make the image's packages (its ROCm torch) importable from the project venv. A .pth file is used
# instead of --system-site-packages because the image's torch may itself live in a venv/conda env,
# which --system-site-packages would skip.
venv_site="$("$venv/bin/python" -c 'import sysconfig; print(sysconfig.get_path("purelib"))')"
"$image_python" -c 'import site; print("\n".join(site.getsitepackages()))' >"$venv_site/_rocm_image.pth"

# Never install torch & co. from PyPI here (e.g. pulled in by accelerate/timm): the image's ROCm
# build must win.
uv sync --quiet --no-dev \
  --no-install-package torch \
  --no-install-package torchvision \
  --no-install-package torchaudio \
  --no-install-package triton \
  --no-install-package pytorch-triton-rocm

exec uv run --no-sync "$@"
