"""Show what PyTorch sees: versions, GPUs and a matmul on each GPU.

On ROCm builds the AMD GPU is the "cuda" device, so code written for
`device="cuda"` works unchanged. With an integrated GPU next to the dedicated
one, pick the card with `HIP_VISIBLE_DEVICES=<index>`.
"""

import torch

print(f"torch {torch.__version__}, HIP {torch.version.hip}")

if not torch.cuda.is_available():
    print("no GPU visible (is the amdgpu driver loaded and /dev/kfd accessible?)")
    raise SystemExit(1)

for i in range(torch.cuda.device_count()):
    props = torch.cuda.get_device_properties(i)
    x = torch.rand(2048, 2048, device=f"cuda:{i}")
    (x @ x).sum().item()
    print(
        f"cuda:{i}  {props.name}  {props.gcnArchName}  "
        f"{props.total_memory / 2**30:.1f} GiB  matmul ok"
    )
