#!/usr/bin/env bash
# Build the interactive installer ISO (disk encryption option, your own user)
# from a published Bastion image, using iso/config.toml.
#
#   ./local-build/build-iso.sh <owner> <image> [tag]
#   ./local-build/build-iso.sh vensder bastion-linux-gnome-minimal
#
# Result: /var/lib/libvirt/iso/<image>-<tag>-<date>.iso
set -euo pipefail
cd "$(dirname "$0")"
. ./common.sh
parse_args "$@"

CONFIG="$OUT_DIR/config.toml"
sed "s#@IMAGE@#${IMAGE_REF}#" ../iso/config.toml > "$CONFIG"

pull_image
apparmor_off
# --net=host: the ISO build downloads installer RPMs from Fedora mirrors, and
# DNS often fails on podman's default bridge (Ubuntu + systemd-resolved).
run_bib "$CONFIG" anaconda-iso --net=host

sudo mv "$OUT_DIR/bootiso/install.iso" "$OUT_DIR/${OUT_NAME}.iso"
(cd "$OUT_DIR" && sha256sum "${OUT_NAME}.iso")
move_result "$OUT_DIR/${OUT_NAME}.iso" /var/lib/libvirt/iso
