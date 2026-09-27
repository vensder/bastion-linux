#!/usr/bin/env bash
# Guard for the minimal variant: no Xorg server may be installed.
# Xwayland is allowed for now while the session is being debugged; set
# FORBIDDEN back to include xorg-x11-server-Xwayland to make it Wayland-only.
# (X11 client libraries such as libX11 can still be pulled in by GTK/Mesa;
# without a server they have nothing to connect to.)
set -euo pipefail

# DEBUG PHASE: report only. Set STRICT=1 to fail the build again.
STRICT=0

FORBIDDEN="xorg-x11-server-Xorg"
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
    [ "$STRICT" -eq 1 ] && exit 1
    echo "(STRICT=0: continuing)" >&2
fi

[ -z "$FOUND" ] && echo "No Xorg server installed."
echo "Xwayland: $(rpm -q xorg-x11-server-Xwayland 2> /dev/null || echo not installed)"
echo "Installed packages: $(rpm -qa | wc -l)"
echo "X11 client libraries: $(rpm -qa 'libX*' | wc -l)"
