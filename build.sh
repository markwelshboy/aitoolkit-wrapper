#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   IMAGE_REPO=markwelshboy/aitoolkit-wrapper TAG=latest ./build.sh
#
# Optional:
#   UPSTREAM=ostris/aitoolkit:0.7.22 IMAGE_REPO=markwelshboy/aitoolkit-wrapper TAG=0.7.22 ./build.sh

IMAGE_REPO="${IMAGE_REPO:-markwelshboy/aitoolkit-wrapper}"
TAG="${TAG:-latest}"
UPSTREAM="${UPSTREAM:-ostris/aitoolkit:latest}"

echo "[build] upstream: $UPSTREAM"
echo "[build] target  : ${IMAGE_REPO}:${TAG}"

# Create a temp Dockerfile with the chosen upstream
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -v upstream="$UPSTREAM" '
  BEGIN { done=0 }
  /^FROM[[:space:]]+/ && !done { print "FROM " upstream; done=1; next }
  { print }
' Dockerfile > "$tmp"

sudo docker build -f "$tmp" -t "${IMAGE_REPO}:${TAG}" .
sudo docker push "${IMAGE_REPO}:${TAG}"

echo "[build] pushed: ${IMAGE_REPO}:${TAG}"
