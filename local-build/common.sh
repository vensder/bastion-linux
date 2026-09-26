#!/usr/bin/env bash
# Shared helpers for build-qcow2.sh and build-iso.sh. Not run directly.
#
# Assumes you are already logged in to ghcr.io if the package is private:
#   sudo podman login ghcr.io

BIB_IMAGE=quay.io/centos-bootc/bootc-image-builder:latest
BWRAP_PROFILE=/etc/apparmor.d/bwrap-userns-restrict

usage() {
    echo "Usage: $0 <owner> <image> [tag]" >&2
    echo "  e.g. $0 vensder bastion-linux-gnome-minimal latest" >&2
    exit 2
}

# Sets OWNER, IMAGE, TAG, IMAGE_REF, OUT_DIR from the arguments.
parse_args() {
    [ $# -ge 2 ] && [ $# -le 3 ] || usage
    OWNER=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')   # GHCR needs lowercase
    IMAGE=$2
    TAG=${3:-latest}
    IMAGE_REF="ghcr.io/${OWNER}/${IMAGE}:${TAG}"
    OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/bastion-build.XXXXXX")
    # Name for the result files: <image>-<tag>-<date>
    OUT_NAME="${IMAGE}-${TAG}-$(date +%Y%m%d-%H%M)"
}

# Ubuntu confines bwrap, which osbuild needs. Unload the profile for the
# build only and load it back on exit (also on error or Ctrl-C).
apparmor_off() {
    if [ -f "$BWRAP_PROFILE" ] && command -v apparmor_parser > /dev/null; then
        echo "Unloading AppArmor profile $BWRAP_PROFILE for the build"
        sudo apparmor_parser -R "$BWRAP_PROFILE" || true
        trap apparmor_on EXIT
    fi
}

apparmor_on() {
    echo "Reloading AppArmor profile $BWRAP_PROFILE"
    sudo apparmor_parser -r "$BWRAP_PROFILE" || echo "WARNING: reload failed, run: sudo apparmor_parser -r $BWRAP_PROFILE" >&2
}

pull_image() {
    echo "Pulling $IMAGE_REF"
    sudo podman pull "$IMAGE_REF"
}

# run_bib <config.toml> <type> [extra podman args...]
run_bib() {
    local config=$1 type=$2
    shift 2
    sudo podman run --rm -it --privileged --pull=newer "$@" \
        --security-opt label=type:unconfined_t \
        --security-opt apparmor=unconfined \
        -v "$config":/config.toml:ro \
        -v "$OUT_DIR":/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        "$BIB_IMAGE" \
        --type "$type" --rootfs btrfs \
        "$IMAGE_REF"
}

# move_result <file> <destination dir>
move_result() {
    local src=$1 dest_dir=$2
    sudo mkdir -p "$dest_dir"
    sudo mv "$src" "$dest_dir/"
    if command -v virsh > /dev/null; then
        sudo virsh pool-refresh default > /dev/null 2>&1 || true
    fi
    sudo rm -rf "$OUT_DIR"
    echo "Done: $dest_dir/$(basename "$src")"
}
