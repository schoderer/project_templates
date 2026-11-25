"""Speech to text with Whisper, in the style of the model card.

just run examples/transcribe.py some-audio.mp3
"""

import sys

import torch
from transformers import pipeline

device = "cuda" if torch.cuda.is_available() else "cpu"  # "cuda" is the AMD GPU on ROCm
dtype = torch.float16 if device == "cuda" else torch.float32

if device == "cuda":
    props = torch.cuda.get_device_properties(0)
    print(
        f"Running on GPU: {props.name} ({getattr(props, 'gcnArchName', '?').split(':')[0]})"
    )
else:
    print("Running on CPU (no GPU visible to torch)")

pipe = pipeline(
    "automatic-speech-recognition",
    model="openai/whisper-small",
    dtype=dtype,
    device=device,
)

result = pipe(sys.argv[1], return_timestamps=True)
# a single input gives a single result (narrows the type for ty)
assert isinstance(result, dict)
print(result["text"])
