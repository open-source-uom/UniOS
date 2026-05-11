#!/bin/bash

# Creates a Kubuntu Golden Image using the Ubuntu Server ISO as a base.

# Settings
BASE_ISO="ubuntu-24.04-live-server-amd64.iso"
OUT_ISO="unattended-kubuntu.iso"
IMG_OUT="kubuntu-base-amd64.qcow2"

TMPDIR="tmp"
USERDATA="configs/kubuntu_autoinstall.yaml" 
METADATA="configs/meta-data"

function usage() {
  echo "Usage: $0 [-s size]"
  echo ""
  echo "-s|--size n   Size of the resulting virtual disk (default 28500M)"
  echo "--no-usb      Don't create a fat32 partition for easy usb mounting"
  exit 1
}

USB_PARTITION=1

while [[ $# -ge 1 ]]; do
  key="$1"
  case $key in
    -s|--size)
      IMGSIZE=$2
      shift
      ;;
    --no-usb)
      USB_PARTITION=0
      ;;
    *)
      usage
      ;;
    esac
    shift
done

# Default image size 28500M
IMGSIZE=${IMGSIZE:-28500M} 

# Ensure the Server ISO is present
if [ ! -f "$BASE_ISO" ]; then
    echo "Error: $BASE_ISO not found! Please download the Ubuntu 24.04 Server ISO."
    exit 1
fi

function create_unattended_iso(){
  echo ">>> Extracting base ISO..."
  CONTENTSDIR="$TMPDIR/contents"
  rm -rf "$CONTENTSDIR"
  mkdir -p "$CONTENTSDIR"
  
  # Extract the efi partition out of the iso
  read -a EFI_PARTITION < <(parted -m $BASE_ISO unit b print | awk -F: '$1 == "2" { print $2,$3,$4}' | tr -d 'B')
  sudo dd if=$BASE_ISO of=$TMPDIR/efi.img skip=${EFI_PARTITION[0]} bs=1 count=${EFI_PARTITION[2]} status=none ; sync
  
  # Extract MBR
  dd if=$BASE_ISO of=$TMPDIR/mbr.img bs=1 count=1 status=none ; sync

  # Extract ISO contents
  if hash bsdtar 2>/dev/null; then
    bsdtar xfp $BASE_ISO -C $CONTENTSDIR
    chmod -R u+w "$CONTENTSDIR"
  else
    LOOPDIR="$TMPDIR/iso"
    mkdir -p "$LOOPDIR"
    sudo mount -o loop "$BASE_ISO" "$LOOPDIR"
    cp -rT "$LOOPDIR" "$CONTENTSDIR"
    sudo umount "$LOOPDIR"
  fi

  echo ">>> Injecting Cloud-Init configs for Kubuntu Desktop..."
  mkdir -p "$CONTENTSDIR/autoinst"
  cp "$USERDATA" "$CONTENTSDIR/autoinst/user-data"
  cp "$METADATA" "$CONTENTSDIR/autoinst/meta-data"
  
  if [[ $USB_PARTITION == 0 ]]; then
    sed -i -e "/USB_PARTITION_ENABLED/d" "$CONTENTSDIR/autoinst/user-data"
  fi

  # Configure grub to start the autoinstall automatically
  cat <<EOF > "$CONTENTSDIR/boot/grub/grub.cfg"
set timeout=3
loadfont unicode
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Install Kubuntu Custom (Unattended)" {
    set gfxpayload=keep
    linux    /casper/vmlinuz  autoinstall ds=nocloud\;seedfrom=/cdrom/autoinst/ net.ifnames=0 ---
    initrd   /casper/initrd
}
EOF

  echo ">>> Repacking the Unattended ISO..."
  set -x
  xorriso -as mkisofs -r \
    -V 'ATTENDLESS_KUBUNTU' \
    -o $OUT_ISO \
    --grub2-mbr $TMPDIR/mbr.img \
    -partition_offset 16 \
    --mbr-force-bootable \
    -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b $TMPDIR/efi.img \
    -appended_part_as_gpt \
    -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
    -c '/boot.catalog' \
    -b '/boot/grub/i386-pc/eltorito.img' \
    -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
    -eltorito-alt-boot \
    -e '--interval:appended_partition_2:::' \
    -no-emul-boot \
    $CONTENTSDIR
  set +x

  # cleanup
  rm -rf "$CONTENTSDIR"
}

create_unattended_iso

echo ">>> Creating Virtual Disk and starting QEMU Installation..."
mkdir -p output
rm -f "output/$IMG_OUT"

# Create the blank qcow2 drive
qemu-img create -f qcow2 -o size="$IMGSIZE" "output/$IMG_OUT"

# Boot the VM. We bumped RAM to 8192M because installing a GUI environment is heavy.
set -x
qemu-system-x86_64 \
  --enable-kvm -m 8192 \
  -drive file="output/$IMG_OUT",index=0,media=disk,format=qcow2 \
  -cdrom $OUT_ISO -boot order=d \
  -net nic -net user,hostfwd=tcp::5222-:22,hostfwd=tcp::5280-:80 \
  -vga qxl -vnc :0 \
  -usbdevice tablet \
  -cpu host

set +x
echo ">>> QEMU finished. Your image is located at output/$IMG_OUT"
