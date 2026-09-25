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

## Supply chain

- Image is signed in CI with the key in the `release` environment (main branch only).
- `/etc/containers/policy.json` in the image requires that signature for this image
  and rejects images from every other registry path.
- The image is rebuilt daily to pick up Fedora updates.
