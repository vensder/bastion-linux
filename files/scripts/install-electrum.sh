#!/usr/bin/env bash
# Install the upstream Electrum AppImage into the image, verified against a
# pinned GPG key. To upgrade: change VERSION, rebuild, check the log.
set -euo pipefail

VERSION=4.8.2
# Thomas Voegtlin (Electrum lead developer) release signing key.
# Cross-checked: electrum.org docs and github.com/spesmilo/electrum pubkeys/ThomasV.asc
SIGNER_FPR=6694D8DE7BE8EE5631BED9502BD5824B7F9470E6

BASE_URL="https://download.electrum.org/${VERSION}"
APPIMAGE="electrum-${VERSION}-x86_64.AppImage"
KEY_FILE="$(dirname "$(readlink -f "$0")")/../keys/electrum-ThomasV.asc"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

curl -fsSL --proto '=https' --tlsv1.2 -o "$APPIMAGE"     "${BASE_URL}/${APPIMAGE}"
curl -fsSL --proto '=https' --tlsv1.2 -o "$APPIMAGE.asc" "${BASE_URL}/${APPIMAGE}.asc"

# Verify with a throwaway keyring holding only the key committed to this repo.
# The .asc can carry several signatures; others fail with ERRSIG (no key),
# which is fine. We require a VALIDSIG from the pinned key and no BADSIG.
export GNUPGHOME="$WORK/gnupg"
mkdir -m 700 "$GNUPGHOME"
gpg --batch --quiet --import "$KEY_FILE"
gpg --batch --status-fd 1 --verify "$APPIMAGE.asc" "$APPIMAGE" > status.txt 2> /dev/null || true

if grep -q '^\[GNUPG:\] BADSIG' status.txt; then
    echo "ERROR: bad signature on $APPIMAGE" >&2
    exit 1
fi
if ! awk -v fpr="$SIGNER_FPR" '$2 == "VALIDSIG" && ($3 == fpr || $NF == fpr) { ok = 1 } END { exit !ok }' status.txt; then
    echo "ERROR: no valid signature from $SIGNER_FPR on $APPIMAGE" >&2
    cat status.txt >&2
    exit 1
fi
echo "Electrum ${VERSION}: signature OK (${SIGNER_FPR})"
sha256sum "$APPIMAGE"

# Unpack (no FUSE needed at runtime) into a root-owned, read-only location.
chmod +x "$APPIMAGE"
"./$APPIMAGE" --appimage-extract > /dev/null
rm -rf /usr/lib/electrum
mv squashfs-root /usr/lib/electrum
chown -R root:root /usr/lib/electrum
chmod -R go-w /usr/lib/electrum

# Icon: the AppImage spec puts it at the top level of the image.
ICON=$(find /usr/lib/electrum -maxdepth 1 \( -name '*.png' -o -name '*.svg' \) | head -n 1)
if [ -n "$ICON" ]; then
    install -Dm644 "$ICON" "/usr/share/pixmaps/electrum.${ICON##*.}"
fi

cat > /usr/bin/electrum <<'EOF'
#!/bin/sh
exec /usr/lib/electrum/AppRun "$@"
EOF
chmod 755 /usr/bin/electrum

# Own desktop entry. Deliberately no bitcoin:/lightning: URI handler, so the
# browser cannot launch the wallet with a pre-filled payment.
cat > /usr/share/applications/electrum.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Electrum
Comment=Bitcoin wallet
Exec=/usr/bin/electrum
Icon=electrum
Categories=Finance;Network;
Terminal=false
EOF
