# Bastion Linux

Hardened Fedora Atomic desktop for self-custody Bitcoin wallets, as a research project.
Built with BlueBuild, signed with cosign, published to GHCR.

## Status and disclaimer

**This is an experimental research project, not a finished or audited product.**

- It is provided "as is", without warranty of any kind, express or implied,
  including fitness for a particular purpose. See [LICENSE](LICENSE).
- Use it at your own risk. The authors are not liable for any loss of funds,
  data, or any other damage arising from its use.
- It has not been independently security-audited. Hardening reduces risk; it
  does not make a computer that holds private keys safe.
- Nothing here is financial, legal, or security advice.
- Keep your seed phrase offline (paper or steel). Never type it into a browser,
  photograph it, or store it digitally. Test with small amounts first.
- For significant amounts, a hardware wallet is safer than any software wallet
  on an internet-connected machine.

## What it does

- **Signed, immutable OS image.** Updates are verified against the project's
  cosign key; images from any other registry path are rejected.
- **Nothing listens on the network.** Firewall default zone `drop`; SSH server
  removed; mDNS/LLMNR, CUPS, remote desktop and other network-facing services masked.
- **Less running code.** Unneeded system and GNOME user services masked;
  GNOME Software, Parental Controls and online-account providers removed or disabled.
- **No core dumps**, so process memory (wallet keys) is never written to disk.
- **One update channel.** No Flatpak remotes; the wallet (Electrum) is built
  into the image from the upstream release, GPG-verified against a pinned key.
- **Disposable, sandboxed browser.** LibreWolf runs in a bubblewrap sandbox with an
  in-memory profile and no access to your home folder or the wallet.

## Variants

| Image | Base | Recipe |
|---|---|---|
| `ghcr.io/OWNER/bastion-linux` | Fedora Silverblue (GNOME) | `recipes/recipe-gnome.yml` |
| `ghcr.io/OWNER/bastion-linux-sway` | Fedora Sway Atomic | `recipes/recipe-sway.yml` |

GNOME is the recommended variant: it does not expose screen capture, clipboard
reading or input injection to ordinary apps. Sway (wlroots) does, which matters
for clipboard address-swapping malware. Sway is kept for comparison.

Shared hardening is in `recipes/common.yml`; per-desktop trimming in `recipes/gnome.yml`.
CI builds every variant in parallel. In the commands below, use the image name of the
variant you want.

Every variant trusts all images under `ghcr.io/OWNER/` signed with the same key, so a
machine can switch variants with `ostree-image-signed:` directly, no unverified hop.

## Build your own

You can build and sign your own copy with a free GitHub account. You then trust
your own key and your own build, not someone else's.

1. **Fork** this repository. In the fork, open the **Actions** tab and enable workflows
   (GitHub disables them in forks).
2. **Create a signing key** (needs [cosign](https://github.com/sigstore/cosign)):
   ```sh
   COSIGN_PASSWORD="" cosign generate-key-pair
   ```
   This writes `cosign.key` (private) and `cosign.pub` (public).
3. **Store the private key in a protected environment.** In the fork:
   Settings -> Environments -> New environment `release`. Under "Deployment branches",
   allow only `main`. Add an environment secret `COSIGN_PRIVATE_KEY` with the full
   contents of `cosign.key`.
4. **Commit your public key.** Replace `cosign.pub` in the repository root with yours.
   Then delete `cosign.key` from disk, or move it to offline storage.
5. **Build.** Push to `main` or run the workflow manually (Actions -> Build Bastion Linux
   -> Run workflow). Images appear under your account's Packages as
   `ghcr.io/<your-account>/bastion-linux` and `ghcr.io/<your-account>/bastion-linux-sway`.
6. **Package visibility.** New GHCR packages are private. Either make them public
   (package page -> Package settings -> Change visibility) or run
   `sudo podman login ghcr.io` before pulling.
7. **Install** with the steps below, using your account name as `OWNER`.

Changing the image name: edit `name:` in `recipes/recipe-*.yml`. Everything else
(policy, signing) follows the name and your account automatically.

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

## Build an installer ISO

The ISO is an interactive installer. During install you:

- choose the disk and tick **Encrypt my data** (LUKS2 full-disk encryption; you set the
  disk passphrase and type it at every boot) - **strongly recommended**;
- choose language, keyboard and time zone;
- create your own user and password (tick "Make this user administrator").
  No password is baked into the ISO, and the root account is locked.

The installed system is switched to signed updates (`ostree-image-signed:`) by the
installer, so the manual step 2 of "Install / rebase" is not needed.

### In GitHub Actions (recommended)

Actions -> **Build installer ISO** -> Run workflow, pick the variant. The workflow
verifies the image signature with `cosign.pub`, checks the pulled image is the verified
one, builds the ISO and uploads it with a `.sha256` file as a workflow artifact
(kept 7 days). Download it from the run page and check it:

```sh
sha256sum -c bastion-linux-*.iso.sha256
```

### Locally

Same tool and prerequisites as the qcow2 build (rootful Podman, the Ubuntu AppArmor step).

```sh
IMAGE=ghcr.io/OWNER/bastion-linux:latest
sudo podman pull "$IMAGE"
sed "s#@IMAGE@#${IMAGE}#" iso/config.toml > config-iso.toml

mkdir -p output
# --net=host: the ISO build downloads installer RPMs from Fedora mirrors,
# and DNS often fails on podman's default bridge (e.g. Ubuntu + systemd-resolved).
sudo podman run --rm -it --privileged --pull=newer --net=host \
  --security-opt label=type:unconfined_t \
  --security-opt apparmor=unconfined \
  -v ./config-iso.toml:/config.toml:ro \
  -v ./output:/output \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type anaconda-iso --rootfs btrfs \
  "$IMAGE"
# result: output/bootiso/install.iso
```

Test in a VM with a blank 40 GB disk:

```sh
sudo mv output/bootiso/install.iso /var/lib/libvirt/images/bastion-install.iso
sudo virt-install --name bastion-iso --memory 4096 --vcpus 2 \
  --disk size=40 --cdrom /var/lib/libvirt/images/bastion-install.iso \
  --os-variant fedora-unknown --boot uefi --graphics spice
```

After install, check: `rpm-ostree status` shows `ostree-image-signed:docker://...`,
and `lsblk -f` shows a `crypto_LUKS` partition if you chose encryption.

## Supply chain

- Image is signed in CI with the key in the `release` environment (main branch only).
- `/etc/containers/policy.json` in the image requires that signature for images under
  the owner's GHCR namespace and rejects images from every other registry path.
- GitHub Actions are pinned by commit SHA; Dependabot proposes updates.
- Daily rebuilds (for Fedora updates) are disabled while testing; see `schedule` in `build.yml`.

## Wallet

Electrum is installed from the upstream AppImage at build time
(`files/scripts/install-electrum.sh`):

- The signature must be valid from Thomas Voegtlin's release key
  (`6694 D8DE 7BE8 EE56 31BE D950 2BD5 824B 7F94 70E6`), which is committed
  in `files/keys/`. The key is never fetched at build time.
- Unpacked into `/usr/lib/electrum` (read-only, no FUSE), launched via `/usr/bin/electrum`.
- No `bitcoin:` URI handler, so the browser cannot open the wallet with a pre-filled payment.
- Upgrade: bump `VERSION` in the script. The build log prints the AppImage sha256.

## Browser

LibreWolf replaces Firefox. It is installed from the official LibreWolf RPM repo at
build time; the repo key must match the pinned fingerprint
`662E 3CDD 6FE3 2900 2D0C A5BB 4033 9DD8 2B12 EF16`, and the repo is removed
again after install (`files/scripts/install-librewolf.sh`).

Every launch from the app grid, and every link opened from another app, goes through
`/usr/bin/librewolf-disposable`, a bubblewrap sandbox:

- **Disposable:** the browser's home is in memory. Profile, cookies, cache and history
  are gone when the window closes. You log in to exchanges each time.
- **Cannot see your home folder,** so not the wallet (`~/.electrum`). The only shared
  folder is your Downloads folder (the localised one, e.g. from `xdg-user-dir DOWNLOAD`).
- **Wayland only:** no X11, no D-Bus session bus, no audio.
- Typing `librewolf` in a terminal starts it *without* the sandbox; use the app grid.

No Flatpak remotes are configured; all apps come from the signed image.
On a machine installed before this change: `flatpak uninstall --all && flatpak remote-delete fedora`.

## License

The build configuration and scripts in this repository are licensed under the
[Apache License 2.0](LICENSE). The resulting OS images contain Fedora, Electrum and
other software, each under its own license.
