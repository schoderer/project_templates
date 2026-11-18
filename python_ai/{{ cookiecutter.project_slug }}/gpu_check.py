"""Checks that torch sees the AMD GPU (ROCm devices show up as "cuda")."""

import torch

print(f"torch {torch.__version__} from {torch.__file__}")
print(f"HIP/ROCm: {torch.version.hip or 'no (CPU or CUDA build)'}")
print(f"GPU available: {torch.cuda.is_available()}")

for i in range(torch.cuda.device_count()):
    props = torch.cuda.get_device_properties(i)
    arch = getattr(props, "gcnArchName", "?")
    print(f"  [{i}] {props.name} ({arch}, {props.total_memory / 2**30:.1f} GiB)")

if torch.cuda.is_available():
    a = torch.randn(4096, 4096, device="cuda")
    b = a @ a
    torch.cuda.synchronize()
    print(f"matmul on GPU ok: {tuple(b.shape)}")
