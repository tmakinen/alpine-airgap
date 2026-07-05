#!/bin/sh
# shellcheck disable=SC2034

profile_airgap() {
    profile_base

    title="Airgapped"
    desc="Secure baseline environment designed exclusively for offline operations. Includes a pre-packaged suite of utilities required to perform core standalone tasks without network access."

    image_ext="iso"
    arch="x86_64"

    apks="${apks} bash cryptsetup git gpm kbd-bkeymaps"
    apkovl="genapkovl-airgap.sh"

    hostname="airgap"
}
