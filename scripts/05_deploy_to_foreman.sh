#!/usr/bin/env bash
#  1. Mount the finished ISO under /var/www/html so Foreman
#     can serve it via HTTP (the "mirror" strategy).
#  2. Update the Foreman Installation Medium via API so it
#     always points to the latest build.
#
#  This is the "Automation Bridge" - called from CI/CD after
#  04_build_iso.sh succeeds.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
OUTPUT_ISO="${REPO_ROOT}/output/kubuntu-custom.iso"

# Foreman config - these need configuring.
FOREMAN_HOST="https://foreman.example.com"   # ← your Foreman URL
FOREMAN_USER="admin"
FOREMAN_PASS="${FOREMAN_PASSWORD:-changeme}"  # set via env var in CI
FOREMAN_MEDIUM_ID="1"                        # ← ID of your Installation Medium in Foreman
FOREMAN_MEDIUM_NAME="Kubuntu-Custom-KDE"

# Web server mount point
WEB_ROOT="/var/www/html/pub"
MOUNT_POINT="${WEB_ROOT}/kubuntu-custom"

if [[ ! -f "$OUTPUT_ISO" ]]; then
    echo "ERROR: ISO not found at $OUTPUT_ISO. Run 04_build_iso.sh first."
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required."
    exit 1
fi

# Mount ISO to web root
echo "[1/2] Mounting ISO to web server..."
mkdir -p "$MOUNT_POINT"

if mountpoint -q "$MOUNT_POINT"; then
    echo "  Already mounted — unmounting old version first."
    umount "$MOUNT_POINT"
fi

mount -o loop,ro "$OUTPUT_ISO" "$MOUNT_POINT"
echo "  Mounted: $OUTPUT_ISO → $MOUNT_POINT"
echo "  Accessible at: http://$(hostname -f)/pub/kubuntu-custom/"

# Update Foreman Installation Medium via API
echo "[2/2] Updating Foreman Installation Medium (ID: $FOREMAN_MEDIUM_ID)..."

HTTP_CODE=$(curl -s -o /tmp/foreman_response.json -w "%{http_code}" \
    -u "${FOREMAN_USER}:${FOREMAN_PASS}" \
    -X PUT \
    -H "Content-Type: application/json" \
    "${FOREMAN_HOST}/api/media/${FOREMAN_MEDIUM_ID}" \
    -d "{
        \"medium\": {
            \"name\": \"${FOREMAN_MEDIUM_NAME}\",
            \"path\": \"http://$(hostname -f)/pub/kubuntu-custom/\"
        }
    }")

if [[ "$HTTP_CODE" == "200" ]]; then
    echo "  ✓ Foreman medium updated successfully."
else
    echo "  ✗ Foreman API returned HTTP $HTTP_CODE"
    echo "  Response: $(cat /tmp/foreman_response.json)"
    exit 1
fi

echo ""
echo "  Deploy complete."
echo "  In Foreman: Hosts > Installation Media > '${FOREMAN_MEDIUM_NAME}'"
echo "  Set a host to Build and Foreman will pull your custom Kubuntu ISO."
