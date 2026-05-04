# UniOS
A custom Linux distribution tailored to the need of the modern Greek university

## Prerequisites

```bash
sudo apt install ansible squashfs-tools xorriso rsync qemu-system-x86
```

## Repository Structure

```
UniOS/
├── scripts/
│   ├── 01_extract_iso.sh        # Mount ISO, extract squashfs → chroot
│   ├── 02_setup_chroot.sh       # Bind/mount /dev /proc /run /sys
│   ├── 03_run_ansible.sh        # Run Ansible playbook against chroot
│   ├── 04_build_iso.sh          # Repack chroot → bootable ISO
│   ├── 05_deploy_to_foreman.sh  # Mount ISO to /var/www, update Foreman API
│   └── 06_test_in_qemu.sh       # Boot the custom ISO in QEMU for testing
├── ansible/
│   ├── inventory.ini            # Template inventory (runtime one is generated)
│   ├── playbook.yml             # Main playbook
│   ├── group_vars/
│   │   └── all.yml              # Shared variables (packages, KDE settings)
│   └── roles/
│       ├── desktop-config/      # KDE Plasma config via kwriteconfig5
│       ├── packages/            # Apt install/remove
│       └── plymouth/            # Boot splash theme
├── foreman/
│   ├── provisioning_template.erb  # Finish template snippet for Foreman
│   └── setup_foreman_medium.py    # Python script to register ISO in Foreman API
├── iso_base/                    # (gitignored) Kubuntu ISO
├── build/                       # (gitignored) Working directory
└── output/                      # (gitignored) Final ISO output
```

## Build Pipeline (run as root)

```bash
sudo ./scripts/01_extract_iso.sh    # Extract ISO -> build/chroot
sudo ./scripts/02_setup_chroot.sh   # Bind/mount dev/proc/run/sys
sudo ./scripts/03_run_ansible.sh    # Apply KDE config via Ansible
sudo ./scripts/04_build_iso.sh      # Repack -> output/kubuntu-custom.iso
     ./scripts/06_test_in_qemu.sh   # Test in QEMU (no sudo needed for KVM)
sudo ./scripts/05_deploy_to_foreman.sh  # Push to Foreman
```