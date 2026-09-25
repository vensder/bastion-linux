# Bastion Linux

Hardened Fedora Atomic (Silverblue) desktop for self-custody cryptocurrency wallets.
Built with BlueBuild, signed with cosign, published to GHCR.

## Install / rebase

From any Fedora Atomic desktop. Replace `OWNER` with the GitHub account.

```sh
# 1. First hop: the current system does not know our key yet.
rpm-ostree rebase ostree-unverified-registry:ghcr.io/OWNER/bastion-linux:latest
systemctl reboot

# 2. Switch to the signature-enforced transport. All later updates are verified.
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/OWNER/bastion-linux:latest
systemctl reboot
```

Check: `rpm-ostree status` must show `ostree-image-signed:docker://...` for the booted deployment.

## Build a qcow2 for a test VM

Uses [bootc-image-builder](https://github.com/osbuild/bootc-image-builder).
Needs rootful Podman (`sudo`); Docker will not work.

`config.toml` (test VM only, the password is plain text):

```toml
[[customizations.user]]
name = "tester"
password = "changeme"
groups = ["wheel"]

[[customizations.filesystem]]
mountpoint = "/"
minsize = "40 GiB"
```

Build:

```sh
sudo podman login ghcr.io          # only if the package is private
sudo podman pull ghcr.io/OWNER/bastion-linux:latest

mkdir -p output
sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  --security-opt apparmor=unconfined \
  -v ./config.toml:/config.toml:ro \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 --rootfs btrfs \
  ghcr.io/OWNER/bastion-linux:latest
# result: output/qcow2/disk.qcow2
```

**Ubuntu hosts:** the `bwrap-userns-restrict` AppArmor profile blocks osbuild
(`mount: /run/osbuild/containers/storage: permission denied`). Unload it only for the build:

```sh
sudo apparmor_parser -R /etc/apparmor.d/bwrap-userns-restrict
# ... run the build ...
sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict
```

Run with libvirt:

```sh
sudo mv output/qcow2/disk.qcow2 /var/lib/libvirt/images/bastion-test.qcow2
sudo virsh pool-refresh default
```

Then in virt-manager: New VM, "Import existing disk image", firmware UEFI.
After the first boot, do step 2 of "Install / rebase" to switch to the signed transport.

## Supply chain

- Image is signed in CI with the key in the `release` environment (main branch only).
- `/etc/containers/policy.json` in the image requires that signature for this image
  and rejects images from every other registry path.
- Daily rebuilds (for Fedora updates) are disabled while testing; see `schedule` in `build.yml`.
