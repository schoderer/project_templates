# {{ cookiecutter.project_name }}

Run Hugging Face models (speech, vision, detection, …) on an AMD GPU. Code is edited on the host
(Nix devShell: python 3.14, uv, ty, ruff) and executed in a `rocm/pytorch` podman container with
the project folder mounted at `/workspace`.

## GPU workflow

```sh
just build-image                         # once (the base image is large)
just gpu-info                            # GPUs ROCm sees
just run gpu_check.py                    # torch + HIP + a matmul on the GPU
just run examples/detect.py photo.jpg    # object detection (DETR)
just run examples/transcribe.py talk.mp3 # speech to text (Whisper)
just exec <cmd>                          # any command, e.g. `just exec hf download <model>`
just shell                               # bash in the container
```

On ROCm builds of torch the AMD GPU is the `"cuda"` device, so model-card snippets using
`device="cuda"`, `.to("cuda")` or `device_map="auto"` work unchanged: paste them into a script and
`just run` it. Add libraries with `uv add <pkg>`; the container picks them up on the next run.

Libraries that don't use torch for inference (`faster-whisper`/CTranslate2, plain `onnxruntime`, …)
have no ROCm wheels on PyPI and run on the CPU. Prefer the `transformers` variant of a model.

## How the two environments fit together

- **Host**: `just sync` creates `.venv` with a **CPU** torch (from the PyTorch CPU index), only so
  `ty` (`just check`) and editors can resolve imports.
- **Container**: the venv lives on the podman volume `{{ cookiecutter.project_slug }}-venv`, not in the
  mounted project. torch, torchvision and torchaudio come from the image (its ROCm build) and are
  never installed from PyPI there. `just reset-venv` throws the venv away.
- Downloaded models are shared with the host via `$HF_HOME` (default `~/.cache/huggingface`).
- The image's Python version must match `python314` in `flake.nix` and `requires-python` in
  `pyproject.toml`. When bumping the image in `Containerfile`, keep its `py3.X` in sync.

## Environment variables (read by `just run/exec/shell`)

| Variable                   | Purpose                                                       |
| -------------------------- | ------------------------------------------------------------- |
| `HF_TOKEN`                 | gated / private models                                        |
| `HIP_VISIBLE_DEVICES`      | pick a GPU when several are installed, e.g. `0`               |
| `HSA_OVERRIDE_GFX_VERSION` | run on GPUs ROCm doesn't officially support, e.g. `10.3.0` for RDNA2 |
| `HF_HOME`                  | host model cache directory                                     |
