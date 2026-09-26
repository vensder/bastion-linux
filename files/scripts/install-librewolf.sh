#!/usr/bin/env bash
# Install LibreWolf from its official RPM repo (key pinned by fingerprint),
# replace Firefox, and route every launch through the disposable sandbox.
set -euo pipefail

# LibreWolf RPM signing key, from https://librewolf.net/installation/fedora/
KEY_FPR=662E3CDD6FE329002D0CA5BB40339DD82B12EF16
KEY_URL=https://repo.librewolf.net/pubkey.gpg
KEY_DEST=/etc/pki/rpm-gpg/RPM-GPG-KEY-librewolf

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
export GNUPGHOME="$WORK/gnupg"
mkdir -m 700 "$GNUPGHOME"

# The downloaded key is only accepted if it is exactly the pinned key.
curl -fsSL --proto '=https' --tlsv1.2 -o "$WORK/key" "$KEY_URL"
FPRS=$(gpg --batch --with-colons --show-keys "$WORK/key" \
       | awk -F: '/^pub/ { p = 1; next } /^fpr/ && p { print $10; p = 0 }')
if [ "$FPRS" != "$KEY_FPR" ]; then
    echo "ERROR: LibreWolf key mismatch. Expected $KEY_FPR, got: $FPRS" >&2
    exit 1
fi
install -Dm644 "$WORK/key" "$KEY_DEST"

# Repo exists only for this install; the image stays the single update channel.
cat > /etc/yum.repos.d/librewolf.repo <<EOF
[librewolf]
name=LibreWolf Software Repository
baseurl=https://repo.librewolf.net
gpgcheck=1
repo_gpgcheck=1
gpgkey=file://$KEY_DEST
enabled=1
EOF
dnf5 -y install librewolf
rm -f /etc/yum.repos.d/librewolf.repo

# Remove Firefox. rpm -e (not dnf) fails loudly if something depends on it.
FIREFOX_PKGS=$(rpm -qa --qf '%{NAME}\n' 'firefox*' | tr '\n' ' ')
if [ -n "$FIREFOX_PKGS" ]; then
    # shellcheck disable=SC2086
    rpm -e $FIREFOX_PKGS
fi

# Point the packaged desktop entry at the sandbox wrapper.
DESKTOP=$(rpm -ql librewolf | grep -E '/applications/[^/]+\.desktop$' | head -n 1)
if [ -z "$DESKTOP" ]; then
    echo "ERROR: no LibreWolf desktop file found" >&2
    exit 1
fi
# Replace only the command (first word, any path ending in "librewolf"),
# keep the arguments: /usr/share/librewolf/librewolf %u -> librewolf-disposable %u
sed -E -i 's#^Exec=[^ ]*librewolf( |$)#Exec=/usr/bin/librewolf-disposable\1#' "$DESKTOP"
if grep -E '^Exec=' "$DESKTOP" | grep -v -q 'librewolf-disposable'; then
    echo "ERROR: unrewritten Exec line in $DESKTOP:" >&2
    grep -E '^Exec=' "$DESKTOP" >&2
    exit 1
fi

# Default browser for links opened from other apps (e.g. Electrum).
DESKTOP_ID=$(basename "$DESKTOP")
cat > /etc/xdg/mimeapps.list <<EOF
[Default Applications]
x-scheme-handler/http=$DESKTOP_ID
x-scheme-handler/https=$DESKTOP_ID
text/html=$DESKTOP_ID
EOF

# Sandbox wrapper comes from files/system via the files module.
chmod 755 /usr/bin/librewolf-disposable

echo "LibreWolf installed: $(rpm -q librewolf); desktop entry: $DESKTOP_ID"
