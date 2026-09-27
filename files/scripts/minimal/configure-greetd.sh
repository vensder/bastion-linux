#!/usr/bin/env bash
# greetd runs the graphical greeter (bastion-greeter: gtkgreet in cage, falling
# back to tuigreet) on tty1; the greeter starts the Bastion LXQt session.
# Only the greeter command is changed; the packaged unprivileged greeter user stays.
set -euo pipefail

CONF=/etc/greetd/config.toml
CMD='command = "/usr/bin/bastion-greeter"'

if [ ! -f "$CONF" ]; then
    echo "ERROR: $CONF not found; is greetd installed?" >&2
    exit 1
fi
if ! grep -q '^command *=' "$CONF"; then
    echo "ERROR: no 'command =' line in $CONF" >&2
    cat "$CONF" >&2
    exit 1
fi

sed -i "s#^command *=.*#${CMD}#" "$CONF"
chmod 755 /usr/bin/bastion-session /usr/bin/bastion-greeter

# Boot to the graphical login.
systemctl set-default graphical.target

echo "greetd config:"
cat "$CONF"
