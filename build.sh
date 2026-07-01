#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
    echo "Usage: $(basename "$0") <alpine_linux_version_tag>" 1>&2
    exit 1
fi
ALPINE_TAG="$1"

cd "$(dirname "$0")"

tmpdir="$(mktemp -d -p .)"
trap 'rm -rf -- "$tmpdir"' EXIT

podman build -t "alpine-airgap-builder:${ALPINE_TAG}" \
    --build-arg "ALPINE_TAG=${ALPINE_TAG}" .
podman run -v "${tmpdir}:/build:Z" --rm "alpine-airgap-builder:${ALPINE_TAG}"

cp "${tmpdir}/alpine-airgap-${ALPINE_TAG}-x86_64.iso" .
