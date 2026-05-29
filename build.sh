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
mkdir -p "${tmpdir}/apkovl/etc/apk"
echo "airgap" > "${tmpdir}/apkovl/etc/hostname"
cat <<EOF > "${tmpdir}/apkovl/etc/apk/world"
openssl
openssh-client
cdrkit
dvd+rw-tools
linux-modules-extra
EOF
tar --owner=0 --group=0 -C "${tmpdir}/apkovl" -zcvf \
	"${tmpdir}/iso/airgap.apkovl.tar.gz" .

echo "Configuring boot loader..."
sed -i \
    -e '/^DEFAULT /s/$$/ -ram/' \
    -e '/APPEND/s/$$/ apkovl=\/airgap-ca.apkovl.tar.gz toram/' \
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
