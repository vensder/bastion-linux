#!/usr/bin/env bash
# Guard for the minimal variant: no X server may be installed.
# (X11 client libraries such as libX11 can still be pulled in by GTK/Mesa;
# without a server they have nothing to connect to.)
set -euo pipefail

FORBIDDEN="xorg-x11-server-Xwayland xorg-x11-server-Xorg xorg-x11-server-common"
FOUND=""
for pkg in $FORBIDDEN; do
    if rpm -q --quiet "$pkg"; then
        FOUND="$FOUND $pkg"
    fi
done
if [ -n "$FOUND" ]; then
    echo "ERROR: X server packages installed:$FOUND" >&2
    for pkg in $FOUND; do
        echo "--- required by:" >&2
        rpm -q --whatrequires "$pkg" >&2 || true
    done
    exit 1
fi

echo "No X server installed."
echo "Installed packages: $(rpm -qa | wc -l)"
echo "X11 client libraries: $(rpm -qa 'libX*' | wc -l)"
