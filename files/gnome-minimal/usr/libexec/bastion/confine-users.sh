#!/bin/sh
# Confined SELinux users, run at boot by bastion-confine-users.service.
#
#  - Members of group "bastion-confined" log in as staff_u: SELinux policy
#    applies to their programs, and (staff_exec_content off) they cannot
#    execute files from their home folder or /tmp. Programs from the read-only
#    image (/usr) still run. Not in wheel, so no sudo.
#    (user_u was tried first: Fedora's policy blocks its GNOME login, the
#    user session cannot create its D-Bus socket.)
#  - Everyone else keeps the Fedora default (unconfined_u). This must include
#    system accounts: GDM's login screen runs as its own user, and mapping it
#    to user_u leaves a black screen. So "__default__" is never confined.
#
# Daily use (wallet, browser) happens in a separate account in that group:
#   sudo useradd -m -G bastion-confined wallet && sudo passwd wallet
#
# All changes go into one `semanage import` (one policy rebuild), and only
# when something differs from the wanted state.
set -eu

CONFINED_GROUP=%bastion-confined
CONFINED_USER=staff_u
CONFINED_RANGE=s0-s0:c0.c1023     # allowed range differs per SELinux user (`semanage user -l`)
DEFAULT_USER=unconfined_u
DEFAULT_RANGE=s0-s0:c0.c1023

LOGINS=$(semanage login -l)
mapped() { printf '%s\n' "$LOGINS" | awk -v n="$1" '$1 == n { print $2 }'; }

CMDS=""
# Repair: earlier test builds mapped __default__ to a confined user.
if [ "$(mapped __default__)" != "$DEFAULT_USER" ]; then
    CMDS="${CMDS}login -m -s $DEFAULT_USER -r $DEFAULT_RANGE __default__
"
fi
case "$(mapped "$CONFINED_GROUP")" in
    "$CONFINED_USER") ;;
    "") CMDS="${CMDS}login -a -s $CONFINED_USER -r $CONFINED_RANGE $CONFINED_GROUP
" ;;
    *)  CMDS="${CMDS}login -m -s $CONFINED_USER -r $CONFINED_RANGE $CONFINED_GROUP
" ;;
esac
for BOOL in staff_exec_content user_exec_content; do
    if getsebool "$BOOL" 2> /dev/null | grep -q -- '--> on$'; then
        CMDS="${CMDS}boolean -m --off $BOOL
"
    fi
done

# Extra policy rules for a confined GNOME session. Installed (one more policy
# rebuild) only when missing or changed since the last install.
MODULE=/usr/share/selinux/bastion/bastion_staff.cil
STAMP=/var/lib/bastion/bastion_staff.sha256
WANT=$(sha256sum "$MODULE" | cut -d' ' -f1)
if [ "$(cat "$STAMP" 2> /dev/null)" != "$WANT" ] || ! semodule -l | grep -qx bastion_staff; then
    echo "Installing SELinux module $MODULE"
    semodule -i "$MODULE"
    mkdir -p "$(dirname "$STAMP")"
    echo "$WANT" > "$STAMP"
fi

if [ -n "$CMDS" ]; then
    echo "Applying (one policy rebuild, can take a minute):"
    printf '%s' "$CMDS"
    printf '%s' "$CMDS" | semanage import
fi

echo "Confined users: $CONFINED_GROUP -> $CONFINED_USER (no exec from home and /tmp); others -> $DEFAULT_USER."
