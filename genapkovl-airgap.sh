#!/bin/sh -e

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
    echo "usage: $0 hostname"
    exit 1
fi

cleanup() {
    rm -rf "$tmp"
}

makefile() {
    OWNER="$1"
    PERMS="$2"
    FILENAME="$3"
    mkdir -p "$(dirname "$FILENAME")"
    cat > "$FILENAME"
    chown "$OWNER" "$FILENAME"
    chmod "$PERMS" "$FILENAME"
}

rc_add() {
    mkdir -p "${tmp}/etc/runlevels/${2}"
    ln -sf /etc/init.d/"$1" "${tmp}/etc/runlevels/${2}/${1}"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

makefile root:root 0644 "${tmp}/etc/hostname" <<EOF
$HOSTNAME
EOF

makefile root:root 0644 "${tmp}/etc/apk/world" <<"EOF"
alpine-base
bash
cryptsetup
doas
e2fsprogs
git
gnupg
gpm
jq
kbd-bkeymaps
make
openssh-client
openssl
setup-keymap
shellcheck
vim
xz
yq-go
EOF

rc_add devfs sysinit
rc_add hwdrivers sysinit
rc_add mdev sysinit
rc_add modloop sysinit
rc_add procfs sysinit
rc_add sysfs sysinit

rc_add bootmisc boot
rc_add hostname boot
rc_add hwclock boot
rc_add localmount boot
rc_add modules boot
rc_add sysctl boot
rc_add urandom boot

rc_add gpm default

rc_add killprocs shutdown
rc_add mount-ro shutdown

makefile root:root 0644 "${tmp}/etc/conf.d/loadkmap" <<"EOF"
KEYMAP="/usr/share/bkeymaps/fi/fi-winkeys.bmap.gz"
EOF
rc_add loadkmap boot

if [ -d "${ROOTFS}/etc" ]; then
    for f in passwd group shadow ; do
        cp -a "${ROOTFS}/etc/${f}" "${tmp}/etc/${f}"
    done
    echo "airgap:x:1000:" >> "${tmp}/etc/group"
    echo "airgap:x:1000:1000:Airgap User:/workspace:/bin/bash" >> "${tmp}/etc/passwd"
    echo "airgap:::0:::::" >> "${tmp}/etc/shadow"
fi

mkdir -p "${tmp}/etc/doas.d" "${tmp}/etc/profile.d"
makefile root:root 0600 "${tmp}/etc/doas.d/power.conf" <<"EOF"
permit persist :airgap
permit nopass airgap as root cmd poweroff
permit nopass airgap as root cmd reboot
EOF
makefile root:root 0644 "${tmp}/etc/profile.d/power.sh" <<"EOF"
if [ "$(id -u)" != "0" ]; then
    alias poweroff="doas poweroff"
    alias reboot="doas reboot"
fi
EOF

mkdir -p /workspace
makefile root:root 0755 "${tmp}/etc/init.d/encrypted-workspace" <<"EOF"
#!/sbin/openrc-run

description="Manages volatile encrypted RAM workspace"

depend() {
    need localmount
    after bootmisc
}

start() {
    ebegin "Initializing encrypted RAM workspace"
    dd if=/dev/zero of=/run/workspace.img bs=1M count=100 status=none
    _loopdev="$(losetup -f)"
    losetup "$_loopdev" /run/workspace.img

    dd if=/dev/urandom bs=32 count=1 status=none | cryptsetup open --type plain "$_loopdev" encrypted-workspace --cipher aes-xts-plain64 --key-size 512 -d -
    mkfs.ext4 -q /dev/mapper/encrypted-workspace

    mkdir /workspace
    mount -t ext4 /dev/mapper/encrypted-workspace /workspace
    chown airgap:airgap /workspace
    chmod 0700 /workspace

    eend $?
}

stop() {
    ebegin "Tearing down encrypted RAM workspace"

    umount -l /workspace
    cryptsetup close encrypted-workspace
    losetup -d "$(losetup -a | awk -F: '/\/run\/workspace\.img$/ { print $1 }')"
    dd if=/dev/zero of=/run/workspace.img bs=1M count=10 status=none
    rm -f /run/workspace.img

    eend $?
}
EOF
rc_add encrypted-workspace boot

makefile root:root 0644 "${tmp}/etc/motd" <<"EOF"

# ALPINE LINUX - VOLATILE WORKSTATION

 * Security:  All operations run entirely within volatile memory.
 * Workspace: Encrypted /workspace is automatically destroyed on poweroff.
 * Network:   Fully isolated airgapped host environment.

 WARNING: Any power loss, system reboot, or crash will permanently
          and instantly destroy all data residing within /workspace.

EOF

tar -c -C "$tmp" etc | gzip -9n > "${HOSTNAME}.apkovl.tar.gz"
