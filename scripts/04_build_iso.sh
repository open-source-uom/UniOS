#!/usr/bin/env bash
#  1. Unmount chroot bind mounts (cleanup)
#  2. Repack the chroot into a new squashfs
#  3. Update the filesystem manifest
#  4. Build a bootable ISO with xorriso
#  Run as root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHROOT_DIR="${REPO_ROOT}/build/chroot"
ISO_TREE="${REPO_ROOT}/build/iso_tree"
OUTPUT_ISO="${REPO_ROOT}/output/kubuntu-custom.iso"
ISO_LABEL="KUBUNTU_CUSTOM"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

for cmd in mksquashfs xorriso; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: '$cmd' not found."
        echo "Install with: sudo apt install squashfs-tools xorriso"
        exit 1
    fi
done

# Unmount chroot bind mounts
echo "[1/4] Unmounting chroot bind mounts..."
for mnt in /sys /run /proc /dev/pts /dev; do
    TARGET="${CHROOT_DIR}${mnt}"
    if mountpoint -q "$TARGET" 2>/dev/null; then
        umount "$TARGET"
        echo "  Unmounted: $TARGET"
    fi
done

# Repack squashfs
SQUASHFS_OUT="${ISO_TREE}/casper/filesystem.squashfs"
echo "[2/4] Packing new squashfs → $SQUASHFS_OUT ..."
rm -f "$SQUASHFS_OUT"
mksquashfs "$CHROOT_DIR" "$SQUASHFS_OUT" \
    -comp xz \
    -e boot \
    -noappend
echo "  Done."

# Update filesystem manifest
echo "[3/4] Updating filesystem.manifest..."
chroot "$CHROOT_DIR" dpkg-query -W --showformat='${Package} ${Version}\n' \
    > "${ISO_TREE}/casper/filesystem.manifest"
printf $(du -sx --block-size=1 "$CHROOT_DIR" | cut -f1) \
    > "${ISO_TREE}/casper/filesystem.size"
echo "  Done."

# Build bootable ISO
echo "[4/4] Building bootable ISO → $OUTPUT_ISO ..."
mkdir -p "$(dirname "$OUTPUT_ISO")"

xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "$ISO_LABEL" \
    -output "$OUTPUT_ISO" \
    -eltorito-boot boot/grub/bios.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --eltorito-catalog boot/grub/boot.cat \
    --grub2-boot-info \
    --grub2-mbr "${ISO_TREE}/boot/grub/i386-pc/boot_hybrid.img" \
    -eltorito-alt-boot \
    -e EFI/efiboot.img \
    -no-emul-boot \
    -append_partition 2 0xef "${ISO_TREE}/EFI/efiboot.img" \
    -m "${ISO_TREE}/EFI/efiboot.img" \
    -m "${ISO_TREE}/boot/grub/bios.img" \
    -graft-points \
    "${ISO_TREE}" \
    /boot/grub/bios.img="${ISO_TREE}/boot/grub/bios.img" \
    /EFI/efiboot.img="${ISO_TREE}/EFI/efiboot.img"

echo ""
echo "  ISO built: $OUTPUT_ISO"
