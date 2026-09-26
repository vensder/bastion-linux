#!/usr/bin/env bash
# Fedora's lxqt-wayland-session hard-requires "lxqt-wayland-session-default-compositor",
# and the only package providing it (lxqt-wayland-session-default-compositor-miriway) pulls in the
# miriway compositor, which hard-requires Xwayland. We run LXQt on labwc
# (lxqt-labwc-session), so remove that chain with --nodeps.
#
# Trade-off: the RPM database keeps one unmet dependency (the virtual
# "lxqt-wayland-session-default-compositor"). Nothing runs dnf on an installed
# bootc system, so this only shows up in `rpm -V`/dnf checks, not at runtime.
set -euo pipefail

CHAIN="lxqt-wayland-session-default-compositor-miriway lxqt-miriway-session miriway xorg-x11-server-Xwayland"

INSTALLED=""
for pkg in $CHAIN; do
    if rpm -q --quiet "$pkg"; then
        INSTALLED="$INSTALLED $pkg"
    fi
done
if [ -n "$INSTALLED" ]; then
    echo "Removing (nodeps):$INSTALLED"
    # shellcheck disable=SC2086
    rpm -e --nodeps $INSTALLED
fi

# Drop libraries only miriway used (Mir). Plain rpm -e refuses anything still
# required, so repeat until nothing more can go.
while :; do
    REMOVED=0
    for pkg in $(rpm -qa --qf '%{NAME}\n' 'mir-*' 'libmir*'); do
        if rpm -e "$pkg" 2> /dev/null; then
            echo "Removed unused: $pkg"
            REMOVED=1
        fi
    done
    [ "$REMOVED" -eq 1 ] || break
done
