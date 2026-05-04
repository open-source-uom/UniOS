#!/usr/bin/env bash
#  Execute the Ansible playbook targeting the running QEMU VM
#  over SSH on localhost:2222. No chroot involved.
#  Run AFTER 01_boot_vm.sh confirms SSH is up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="${REPO_ROOT}/ansible"

SSH_PORT="2222"
SSH_USER="kubuntu"
SSH_PASS="kubuntu"       # must match what was set during install

if ! command -v ansible-playbook &>/dev/null; then
    echo "ERROR: ansible-playbook not found."
    echo "Install with: sudo apt install ansible"
    exit 1
fi

# sshpass is needed for password auth; swap for key-based if you prefer
if ! command -v sshpass &>/dev/null; then
    echo "ERROR: sshpass not found."
    echo "Install with: sudo apt install sshpass"
    exit 1
fi

# Write temporary inventory
INVENTORY_FILE=$(mktemp /tmp/qemu_inventory.XXXXXX.ini)
trap 'rm -f "$INVENTORY_FILE"' EXIT

cat > "$INVENTORY_FILE" <<EOF
[custom_distro]
localhost ansible_port=${SSH_PORT} ansible_user=${SSH_USER} ansible_password=${SSH_PASS} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

echo "Running Ansible playbook against QEMU VM (localhost:${SSH_PORT})..."
echo ""

ANSIBLE_HOST_KEY_CHECKING=False \
ansible-playbook \
    -i "$INVENTORY_FILE" \
    "${ANSIBLE_DIR}/playbook.yml" \
    --become \
    --become-method=sudo \
    --become-password-file=<(echo "$SSH_PASS") \
    "$@"

echo ""
echo "  Ansible complete. Run 04_build_iso.sh next."
