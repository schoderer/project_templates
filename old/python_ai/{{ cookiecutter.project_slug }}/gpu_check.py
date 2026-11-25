"""Checks that torch sees the AMD GPU (ROCm devices show up as "cuda")."""

import torch

# Integrated (APU) GPU targets: not supported by ROCm's torch builds
APU_ARCHS = {
    "gfx902",
    "gfx90c",
    "gfx1035",
    "gfx1036",
    "gfx1037",
    "gfx1103",
    "gfx1150",
    "gfx1151",
    "gfx1152",
}

print(f"torch {torch.__version__} from {torch.__file__}")
print(f"HIP/ROCm: {torch.version.hip or 'no (CPU or CUDA build)'}")
print(f"GPU available: {torch.cuda.is_available()}")

archs = []
for i in range(torch.cuda.device_count()):
    props = torch.cuda.get_device_properties(i)
    arch = getattr(props, "gcnArchName", "?").split(":")[0]
    archs.append(arch)
    print(f"  [{i}] {props.name} ({arch}, {props.total_memory / 2**30:.1f} GiB)")

if any(arch in APU_ARCHS for arch in archs):
    print(
        "WARNING: an integrated GPU is visible. Hide it by setting ROCR_VISIBLE_DEVICES in .env "
        "to the UUID of the dedicated card (see `just gpu-info`)."
    )
elif len(archs) > 1:
    print(
        "NOTE: several GPUs are visible; device_map='auto' spreads models over all of them. "
        "Restrict with ROCR_VISIBLE_DEVICES in .env if that's not wanted."
    )

if torch.cuda.is_available():
    a = torch.randn(4096, 4096, device="cuda")
    b = a @ a
    torch.cuda.synchronize()
    print(f"matmul on GPU ok: {tuple(b.shape)}")
