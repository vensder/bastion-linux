#!/bin/sh
# Confined SELinux users, run at boot by bastion-confine-users.service.
#
#  - Members of group "bastion-confined" log in as user_u: SELinux policy
#    applies to their programs, they cannot use sudo, and (user_exec_content
#    off) cannot execute files from their home folder or /tmp. Programs from
#    the read-only image (/usr) still run.
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
CONFINED_USER=user_u
CONFINED_RANGE=s0                 # user_u allows only s0 (see `semanage user -l`)
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
if getsebool user_exec_content 2> /dev/null | grep -q -- '--> on$'; then
    CMDS="${CMDS}boolean -m --off user_exec_content
"
fi

if [ -n "$CMDS" ]; then
    echo "Applying (one policy rebuild, can take a minute):"
    printf '%s' "$CMDS"
    printf '%s' "$CMDS" | semanage import
fi

echo "Confined users: $CONFINED_GROUP -> $CONFINED_USER (no exec from home and /tmp); others -> $DEFAULT_USER."
