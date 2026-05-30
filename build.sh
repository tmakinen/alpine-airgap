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

echo 'KEYMAP="/usr/share/bkeymaps/fi/fi-winkeys.bmap.gz"' > "${apkovl}/etc/loadkmap"
ln -sf "/etc/init.d/loadkmap" "${apkovl}/etc/runlevels/boot/loadkmap"

tar zxvf "${tmpdir}"/iso/apks/x86_64/alpine-baselayout-data-*.apk -C "${apkovl}"\
    etc/group \
    etc/passwd \
    etc/shadow \
    2> /dev/null
echo "airgap:x:1000:" >> "${apkovl}/etc/group"
echo "airgap:x:1000:1000:Airgap User:/workspace:/bin/sh" >> "${apkovl}/etc/passwd"
echo "airgap:::0:::::" >> "${apkovl}/etc/shadow"
sed -i -e 's/^root:/root:\!/' "${apkovl}/etc/shadow"

mkdir -p "${apkovl}/etc/doas.d" "${apkovl}/etc/profile.d"
cat <<EOF > "${apkovl}/etc/doas.d/doas.conf"
permit persist :airgap
permit nopass airgap as root cmd poweroff
permit nopass airgap as root cmd reboot
EOF
cat <<EOF > "${apkovl}/etc/profile.d/reboot.sh"
alias poweroff="doas poweroff"
alias reboot="doas reboot"
EOF

mkdir -p "${apkovl}/etc/local.d" "${apkovl}/etc/runlevels/default"
cat <<"EOF" > "${apkovl}/etc/local.d/encrypted-workspace.start"
#!/bin/sh
set -eu
umask 077
dd if=/dev/zero of=/run/workspace.img bs=1M count=100
_loopdev="$(losetup -f)"
losetup "$_loopdev" /run/workspace.img
dd if=/dev/urandom bs=32 count=1 2> /dev/null | cryptsetup open --type plain "$_loopdev" secure-workspace -d -
mkfs.ext4 /dev/mapper/secure-workspace
mkdir /workspace
mount -t ext4 /dev/mapper/secure-workspace /workspace
chown airgap:airgap /workspace
chmod 0700 /workspace
EOF
ln -s "/etc/init.d/local" "${apkovl}/etc/runlevels/default/local"
chmod +x "${apkovl}/etc/local.d/encrypted-workspace.start"

mkdir -p "${apkovl}/etc/apk"
cat <<EOF > "${apkovl}//etc/apk/world"
alpine-base
cdrkit
cryptsetup
doas
dvd+rw-tools
e2fsprogs
kbd-bkeymaps
linux-lts
openssh-client
openssl
setup-keymap
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
