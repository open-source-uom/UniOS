#!/usr/bin/env bash
#  06_test_in_qemu.sh
#  Boot the finished custom ISO in QEMU to verify it works
#  BEFORE deploying to Foreman.
#
#  Kubuntu minimum system requirements:
#    CPU  : 2 GHz dual-core (2 vCPUs)
#    RAM  : 4 GB
#    Disk : 25 GB virtual disk
#    Video: VGA, 1024×768
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

ISO="${REPO_ROOT}/output/kubuntu-custom.iso"
DISK="${REPO_ROOT}/build/test-disk.qcow2"
DISK_SIZE="25G"
RAM="4G"
CPUS="2"

if ! command -v qemu-system-x86_64 &>/dev/null; then
    echo "ERROR: qemu-system-x86_64 not found."
    echo "Install: sudo apt install qemu-system-x86"
    exit 1
fi

if [[ ! -f "$ISO" ]]; then
    echo "ERROR: Custom ISO not found at $ISO"
    echo "Run 04_build_iso.sh first."
    exit 1
fi

if [[ ! -f "$DISK" ]]; then
    echo "Creating test disk: $DISK ($DISK_SIZE)..."
    qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
fi

echo "Launching custom Kubuntu ISO in QEMU..."
echo "  ISO  : $ISO"
echo "  RAM  : $RAM | CPUs: $CPUS | Disk: $DISK_SIZE"
echo ""

qemu-system-x86_64 \
    -name "Kubuntu-Custom-Test" \
    -machine type=q35,accel=kvm:hvf:whpx:tcg \
    -cpu host \
    -smp "$CPUS" \
    -m "$RAM" \
    -vga std \
    -display default,show-cursor=on \
    -cdrom "$ISO" \
    -drive file="$DISK",format=qcow2,if=virtio \
    -boot order=dc \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -usb \
    -device usb-tablet \
    -audiodev none,id=noaudio
