# CPU-only Linux image for generate.py. Windows Smart App Control blocks PyTorch's native
# DLLs on the host, so generation runs in this container instead (see assets/audio/README.md).
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends git libsndfile1 && rm -rf /var/lib/apt/lists/*
# stable-audio-tools drags in its own torch/torchvision pins; force a matched CPU triplet last
# (torchvision must be built against the exact torch version or `torchvision::nms` fails).
RUN pip install --no-cache-dir stable-audio-tools huggingface_hub \
 && pip install --no-cache-dir --force-reinstall --no-deps \
      torch==2.9.1 torchaudio==2.9.1 torchvision==0.24.1 --index-url https://download.pytorch.org/whl/cpu

WORKDIR /work
ENTRYPOINT ["python", "/work/build/generate.py"]
