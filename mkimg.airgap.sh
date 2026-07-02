#!/bin/sh
# shellcheck disable=SC2034

profile_airgap() {
    profile_base

    image_ext="iso"
    arch="x86_64"
    iso_volume_id="ALPINE_AIRGAP"
    output_filename="alpine-airgap-${ALPINE_TAG:-custom}-${arch}.${image_ext}"

    apks="${apks} bash cryptsetup git gpm kbd-bkeymaps"
    apkovl="genapkovl-airgap.sh"

    hostname="airgap"
}
