#!/bin/sh
# shellcheck disable=SC2034

profile_airgap() {
    profile_base

    title="Airgapped"
    desc="Secure baseline environment designed exclusively for offline operations. Includes a pre-packaged suite of utilities required to perform core standalone tasks without network access."

    image_ext="iso"
    output_format="iso"
    arch="x86_64"

    apkrepos="main community"
    apks="${apks} bash cryptsetup git gnupg gpm jq kbd-bkeymaps make shellcheck vim xz yq-go"
    apkovl="genapkovl-airgap.sh"

    kernel_cmdline="${kernel_cmdline} nomodeset vga=normal"

    hostname="airgap"
}
