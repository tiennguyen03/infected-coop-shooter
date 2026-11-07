#!/usr/bin/env bash
# Build the image once, then generate sounds inside it. Usage (from the repo root, Git Bash):
#   bash assets/audio/build/generate.sh             # all sounds
#   bash assets/audio/build/generate.sh rifle_shot  # a subset
# Mounts assets/audio as /work. The Hugging Face token + model weights live in a Docker
# volume (ras-hf-cache), seeded once from the host's ~/.cache/huggingface: a Windows bind
# mount reads the 2.4 GB of weights at a crawl, a native volume loads them in seconds.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIO_DIR="$(cd "$HERE/.." && pwd)"
HF_CACHE="${HF_HOME:-$HOME/.cache/huggingface}"
IMAGE=ras-audio-gen
VOLUME=ras-hf-cache
export MSYS_NO_PATHCONV=1

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
	docker build -t "$IMAGE" "$HERE"
fi
if ! docker volume inspect "$VOLUME" >/dev/null 2>&1; then
	echo "seeding $VOLUME from $HF_CACHE (one time)"
	docker volume create "$VOLUME" >/dev/null
	docker run --rm --entrypoint sh \
		-v "$(cygpath -w "$HF_CACHE"):/src:ro" -v "$VOLUME:/root/.cache/huggingface" \
		"$IMAGE" -c "cp -r /src/. /root/.cache/huggingface/"
fi
# Keep the token current (the host login can refresh it).
docker run --rm --entrypoint sh \
	-v "$(cygpath -w "$HF_CACHE"):/src:ro" -v "$VOLUME:/root/.cache/huggingface" \
	"$IMAGE" -c "cp /src/token /root/.cache/huggingface/token 2>/dev/null || true"
# The repo root is mounted too so build_banks can write src/shared/SoundBankData.luau.
REPO_DIR="$(cd "$AUDIO_DIR/../.." && pwd)"
docker run --rm \
	-v "$(cygpath -w "$AUDIO_DIR"):/work" \
	-v "$(cygpath -w "$REPO_DIR"):/repo" -e RAS_REPO=/repo \
	-v "$VOLUME:/root/.cache/huggingface" \
	"$IMAGE" "$@"
