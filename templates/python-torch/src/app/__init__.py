def device() -> str:
    """The torch device to use: "cuda" if ROCm sees a GPU, else "cpu".

    ROCm builds of torch expose AMD GPUs as the "cuda" device.
    """
    try:
        import torch
    except ImportError:
        return "cpu"
    return "cuda" if torch.cuda.is_available() else "cpu"
