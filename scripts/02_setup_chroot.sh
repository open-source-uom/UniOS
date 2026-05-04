#!/usr/bin/env bash
#  Bind/mount /dev, /run, /proc, /sys into the chroot so Ansible
#  and apt can "see" the hardware and network.
#  Run as root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHROOT_DIR="${REPO_ROOT}/build/chroot"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if [[ ! -d "$CHROOT_DIR" ]]; then
    echo "ERROR: $CHROOT_DIR does not exist."
    exit 1
fi

bind_mount() {
    local SRC="$1"
    local DST="${CHROOT_DIR}${2:-$1}"
    if mountpoint -q "$DST"; then
        echo "  Already mounted: $DST"
    else
        mount --bind "$SRC" "$DST"
        echo "  Mounted: $SRC → $DST"
    fi
}

echo "Setting up chroot bind mounts..."
bind_mount /dev
bind_mount /dev/pts
bind_mount /proc
bind_mount /run
bind_mount /sys

# Copy host DNS so apt works inside chroot
echo "Copying resolv.conf for DNS..."
cp /etc/resolv.conf "${CHROOT_DIR}/etc/resolv.conf"

echo ""
echo "Chroot ready. Run 03_run_ansible.sh next."
