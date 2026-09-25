#!/usr/bin/env bash
# Set firewalld's default zone to "drop": unsolicited inbound is dropped,
# outbound and replies to it still work.
set -euo pipefail

CONF=/etc/firewalld/firewalld.conf

# Newer firewalld may ship its defaults only under /usr/lib.
if [ ! -f "$CONF" ] && [ -f /usr/lib/firewalld/firewalld.conf ]; then
    mkdir -p /etc/firewalld
    cp /usr/lib/firewalld/firewalld.conf "$CONF"
fi

if grep -q '^DefaultZone=' "$CONF"; then
    sed -i 's/^DefaultZone=.*/DefaultZone=drop/' "$CONF"
else
    echo 'DefaultZone=drop' >> "$CONF"
fi

grep -x 'DefaultZone=drop' "$CONF"
