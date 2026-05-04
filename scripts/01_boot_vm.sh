#!/usr/bin/env bash
#  Boot the Kubuntu ISO in QEMU for an unattended install.
#  Waits until SSH is up on localhost:2222, then exits so
#  03_run_ansible.sh can connect.
#  Doesn't use chroot, and doesn't need sudo
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

ISO="${REPO_ROOT}/iso_base/kubuntu-24.04.2-desktop-amd64.iso"   # ← adjust if needed
DISK="${REPO_ROOT}/build/kubuntu-vm.qcow2"
DISK_SIZE="25G"
RAM="4G"
CPUS="2"
SSH_PORT="2222"          # host port forwarded to VM:22
SSH_USER="kubuntu"
SSH_PASS="kubuntu"       # set by preseed — change if you customise it
PIDFILE="${REPO_ROOT}/build/qemu.pid"
SSH_READY_TIMEOUT=300    # seconds to wait for SSH

# Dependency check
for cmd in qemu-system-x86_64 qemu-img ssh; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: '$cmd' not found."
        exit 1
    fi
done

if [[ ! -f "$ISO" ]]; then
    echo "ERROR: ISO not found at: $ISO"
    exit 1
fi

# Create disk if needed
mkdir -p "${REPO_ROOT}/build"
if [[ ! -f "$DISK" ]]; then
    echo "Creating virtual disk: $DISK ($DISK_SIZE)..."
    qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
fi

# Kill any existing QEMU instance
if [[ -f "$PIDFILE" ]]; then
    OLD_PID=$(cat "$PIDFILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "Stopping existing QEMU (PID $OLD_PID)..."
        kill "$OLD_PID"
        sleep 2
    fi
    rm -f "$PIDFILE"
fi

# Boot QEMU in background
# SSH is forwarded: host:2222 → guest:22
# The Kubuntu live ISO auto-login (user: kubuntu, pass: kubuntu)
# has SSH enabled via the kernel parameter "automatic-ubiquity" +
# preseed. For a full unattended install, supply a preseed via
# initrd injection or an additional seed ISO (see README).
echo "Starting QEMU (daemonized)..."
qemu-system-x86_64 \
    -name "Kubuntu-Build" \
    -machine type=q35,accel=kvm:hvf:whpx:tcg \
    -cpu host \
    -smp "$CPUS" \
    -m "$RAM" \
    -vga std \
    -display none \
    -cdrom "$ISO" \
    -drive file="$DISK",format=qcow2,if=virtio \
    -boot order=dc \
    -netdev user,id=net0,hostfwd=tcp::${SSH_PORT}-:22 \
    -device virtio-net-pci,netdev=net0 \
    -usb \
    -device usb-tablet \
    -daemonize \
    -pidfile "$PIDFILE"

echo "QEMU started (PID $(cat "$PIDFILE")). Waiting for SSH on port $SSH_PORT..."

# Wait for SSH
ELAPSED=0
until ssh -o StrictHostKeyChecking=no \
          -o ConnectTimeout=5 \
          -o PasswordAuthentication=no \
          -o BatchMode=yes \
          -p "$SSH_PORT" \
          "${SSH_USER}@localhost" true 2>/dev/null; do
    if (( ELAPSED >= SSH_READY_TIMEOUT )); then
        echo "ERROR: SSH did not become available within ${SSH_READY_TIMEOUT}s."
        echo "Check if the VM booted correctly. QEMU PID: $(cat "$PIDFILE")"
        exit 1
    fi
    echo "  Waiting for SSH... (${ELAPSED}s elapsed)"
    sleep 10
    ELAPSED=$(( ELAPSED + 10 ))
done

echo ""
echo "  VM is up and SSH is ready on localhost:${SSH_PORT}"
echo "  Run 03_run_ansible.sh next."
