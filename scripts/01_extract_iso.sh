#!/usr/bin/env bash
#  Mount the Kubuntu ISO and extract the squashfs filesystem.
#  Run as root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

ISO="${REPO_ROOT}/iso_base/kubuntu-24.04.2-desktop-amd64.iso"   # ← adjust if needed
ISO_MOUNT="${REPO_ROOT}/build/iso_mount"
SQUASHFS_SRC="casper/filesystem.squashfs"
CHROOT_DIR="${REPO_ROOT}/build/chroot"

# Dependency check
for cmd in unsquashfs mount; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: '$cmd' not found. Install squashfs-tools and util-linux."
        exit 1
    fi
done

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if [[ ! -f "$ISO" ]]; then
    echo "ERROR: ISO not found at: $ISO"
    echo "Place your Kubuntu ISO in iso_base/ and update the ISO variable if needed."
    exit 1
fi

# Mount the ISO
echo "[1/3] Mounting ISO..."
mkdir -p "$ISO_MOUNT"
if mountpoint -q "$ISO_MOUNT"; then
    echo "  Already mounted, skipping."
else
    mount -o loop,ro "$ISO" "$ISO_MOUNT"
    echo "  Mounted at $ISO_MOUNT"
fi

# Copy ISO tree (for later repacking)
ISO_TREE="${REPO_ROOT}/build/iso_tree"
echo "[2/3] Copying ISO tree to build/iso_tree (excluding squashfs)..."
mkdir -p "$ISO_TREE"
rsync -a --exclude="$SQUASHFS_SRC" "$ISO_MOUNT/" "$ISO_TREE/"

# Extract squashfs → chroot
echo "[3/3] Extracting filesystem.squashfs -> build/chroot ..."
if [[ -d "$CHROOT_DIR" ]]; then
    echo "  build/chroot already exists. Delete it to re-extract."
else
    unsquashfs -d "$CHROOT_DIR" "$ISO_MOUNT/$SQUASHFS_SRC"
    echo "  Done: $CHROOT_DIR"
fi

echo ""
echo "Extraction complete."
