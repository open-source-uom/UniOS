#!/usr/bin/env bash
#  Execute the Ansible playbook targeting the chroot directory
#  using the ansible_connection=chroot plugin (no SSH needed).
#  Run as root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHROOT_DIR="${REPO_ROOT}/build/chroot"
ANSIBLE_DIR="${REPO_ROOT}/ansible"

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

if ! command -v ansible-playbook &>/dev/null; then
    echo "ERROR: ansible-playbook not found."
    echo "Install with: sudo apt install ansible"
    exit 1
fi

if [[ ! -d "$CHROOT_DIR" ]]; then
    echo "ERROR: Chroot not found."
    exit 1
fi

# Write a temporary inventory pointing at the chroot
INVENTORY_FILE=$(mktemp /tmp/chroot_inventory.XXXXXX.ini)
trap 'rm -f "$INVENTORY_FILE"' EXIT

cat > "$INVENTORY_FILE" <<EOF
[custom_distro]
${CHROOT_DIR} ansible_connection=chroot
EOF

echo "Running Ansible playbook against chroot: $CHROOT_DIR"
echo ""

ansible-playbook \
    -i "$INVENTORY_FILE" \
    "${ANSIBLE_DIR}/playbook.yml" \
    -e "chroot_dir=${CHROOT_DIR}" \
    "$@"

echo ""
echo "Ansible complete."
