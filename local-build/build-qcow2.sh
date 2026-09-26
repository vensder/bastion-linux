#!/usr/bin/env bash
# Build a qcow2 disk image for a test VM from a published Bastion image.
#
#   ./local-build/build-qcow2.sh <owner> <image> [tag]
#   ./local-build/build-qcow2.sh vensder bastion-linux
#
# Asks for a username and password for the VM (not stored anywhere but the
# image's user database). Result: /var/lib/libvirt/images/<image>-<tag>-<date>.qcow2
set -euo pipefail
cd "$(dirname "$0")"
. ./common.sh
parse_args "$@"

read -r -p "VM username: " VM_USER
read -r -s -p "VM password: " VM_PASS
echo
[ -n "$VM_USER" ] && [ -n "$VM_PASS" ] || { echo "ERROR: username and password required" >&2; exit 1; }
[[ "$VM_USER" =~ ^[a-z_][a-z0-9_-]*$ ]] || { echo "ERROR: username must be lowercase letters, digits, - or _" >&2; exit 1; }

# Escape for a TOML string: backslash and double quote.
VM_PASS=${VM_PASS//\\/\\\\}
VM_PASS=${VM_PASS//\"/\\\"}

CONFIG="$OUT_DIR/config.toml"
umask 077
cat > "$CONFIG" <<EOF
[[customizations.user]]
name = "$VM_USER"
password = "$VM_PASS"
groups = ["wheel"]

[[customizations.filesystem]]
mountpoint = "/"
minsize = "40 GiB"
EOF

pull_image
apparmor_off
run_bib "$CONFIG" qcow2
rm -f "$CONFIG"

sudo mv "$OUT_DIR/qcow2/disk.qcow2" "$OUT_DIR/${OUT_NAME}.qcow2"
move_result "$OUT_DIR/${OUT_NAME}.qcow2" /var/lib/libvirt/images
echo "After first boot, switch to signed updates:"
echo "  sudo rpm-ostree rebase ostree-image-signed:docker://${IMAGE_REF}"
