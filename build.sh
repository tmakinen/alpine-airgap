#!/bin/sh

set -eu

if [ $# -ne 1 ]; then
    echo "Usage: $(basename "$0") <alpine-extended-iso>" 1>&2
    exit 1
fi
ALPINE_ISO="$1"

ALPINE_VERSION="$(xorriso -indev "$ALPINE_ISO" -pvd_info 2>&1 | \
    awk '/^Volume id/ { print $5 }')"

tmpdir="$(mktemp -d -p .)"
trap 'rm -rf -- "$tmpdir"' EXIT

mkdir "${tmpdir}/iso" "${tmpdir}/apkovl"

echo "Extracting ISO image..."
xorriso \
    -osirrox on \
    -indev "$ALPINE_ISO" \
    -find / -exec chmod u+w -- \
    -extract / "${tmpdir}/iso" \
    -rollback_end

echo "Creating custom configuration overlay..."
apkovl="${tmpdir}/apkovl"

mkdir -p "${apkovl}/etc/runlevels/boot"
echo "airgap" > "${apkovl}/etc/hostname"
ln -sf "/etc/init.d/hostname" "${apkovl}/etc/runlevels/boot/hostname"

mkdir -p "${apkovl}/etc/apk"
cat <<EOF > "${apkovl}//etc/apk/world"
alpine-base
cdrkit
dvd+rw-tools
linux-lts
openssh-client
openssl
EOF

tar --owner=0 --group=0 -C "${apkovl}/" -zcvf \
    "${tmpdir}/iso/localhost.apkovl.tar.gz" .

echo "Configuring boot loader..."
sed -i -e 's/^\(APPEND .*\)$/\1toram/' \
    "${tmpdir}/iso/boot/syslinux/syslinux.cfg"

echo "Building new ISO image..."
xorrisofs \
    -o "alpine-airgap-${ALPINE_VERSION}.iso" \
    -b boot/syslinux/isolinux.bin \
    -c boot/syslinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -J -R "${tmpdir}/iso/"
