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

# The greeter user's home (/var/lib/greetd on Fedora) is not created on
# image-based systems, because /var is not part of the image. Let
# systemd-tmpfiles create it at boot so Mesa can keep its shader cache there.
GREETER_USER=$(sed -n 's/^user *= *"\(.*\)"/\1/p' "$CONF" | head -n 1)
GREETER_HOME=$(getent passwd "$GREETER_USER" | cut -d: -f6 || true)
if [ -n "$GREETER_USER" ] && [ -n "$GREETER_HOME" ]; then
    echo "d $GREETER_HOME 0750 $GREETER_USER $GREETER_USER -" > /usr/lib/tmpfiles.d/bastion-greetd.conf
    echo "greeter home: $GREETER_HOME ($GREETER_USER)"
else
    echo "WARNING: greeter user/home not found (user='$GREETER_USER'); skipping tmpfiles entry" >&2
fi

# Boot to the graphical login.
systemctl set-default graphical.target

echo "greetd config:"
cat "$CONF"
