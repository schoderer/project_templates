"""Object detection with DETR, in the style of the model card.

just run examples/detect.py some-image.jpg
"""

import sys

import torch
from transformers import pipeline

device = "cuda" if torch.cuda.is_available() else "cpu"  # "cuda" is the AMD GPU on ROCm

detector = pipeline("object-detection", model="facebook/detr-resnet-50", device=device)

for obj in detector(sys.argv[1]):
    box = obj["box"]
    print(
        f"{obj['label']:>15} {obj['score']:.2f}  "
        f"({box['xmin']}, {box['ymin']}) - ({box['xmax']}, {box['ymax']})"
    )
