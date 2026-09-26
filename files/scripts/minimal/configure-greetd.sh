#!/usr/bin/env bash
# greetd shows tuigreet on tty1 and starts the Bastion Sway session.
# Only the greeter command is changed; the packaged unprivileged greeter user stays.
set -euo pipefail

CONF=/etc/greetd/config.toml
CMD='command = "tuigreet --time --asterisks --cmd /usr/bin/bastion-session"'

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
chmod 755 /usr/bin/bastion-session

# Boot to the graphical login.
systemctl set-default graphical.target

echo "greetd config:"
cat "$CONF"
