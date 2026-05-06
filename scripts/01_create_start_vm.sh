# Author: Apostolos Chalis 2026 <achalis@csd.auth.gr> 
#!/bin/bash

ISO_PATH="./iso_base/kubuntu-25.10-desktop-amd64.iso"  
DISK="dev_disk.qcow2"
MEM="4G"
CORES="4"

if [ ! -f "$ISO_PATH" ]; then
    echo "Error: $ISO not found. Download it first!"
    exit 1
fi

# 2. Check if Disk exists (create if missing)
if [ ! -f "$DISK" ]; then
    echo "Creating new virtual disk..."
    qemu-img create -f qcow2 "$DISK" 40G
fi

echo "Laucnhing QEMU VM..."
qemu-system-x86_64 \
  -enable-kvm \
  -cpu host \
  -smp $CORES \
  -m $MEM \
  -drive file=$DISK,format=qcow2 \
  -cdrom $ISO_PATH \
  -boot d \
  -net nic,model=virtio -net user \
  -vga virtio \
  -display gtk,gl=on
