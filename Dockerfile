ARG ALPINE_TAG
FROM docker.io/library/alpine:${ALPINE_TAG}

ARG ALPINE_TAG
ENV ALPINE_TAG=${ALPINE_TAG}
RUN set -eux ; \
    apk add --no-cache \
        abuild \
        alpine-conf \
        syslinux \
        xorriso \
        squashfs-tools \
        grub \
        mtools \
        git \
        bash

RUN set -eux ; \
    mkdir -p /root/.abuild /etc/apk/keys ; \
    abuild-keygen -a -n

RUN set -eux ; \
    git clone --depth=1 --branch "${ALPINE_TAG}-stable" \
        https://gitlab.alpinelinux.org/alpine/aports.git ; \
    sed -i 's/--no-chown//g' aports/scripts/mkimage.sh

WORKDIR /aports/scripts
COPY genapkovl-airgap.sh mkimg.airgap.sh .

CMD "/bin/sh" "mkimage.sh" \
     "--outdir" "/build" \
     "--arch" "x86_64" \
     "--profile" "airgap" \
     "--tag" "${ALPINE_TAG}" \
     "--repository" "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_TAG}/main"
