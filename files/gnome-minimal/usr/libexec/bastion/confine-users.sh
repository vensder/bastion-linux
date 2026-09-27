#!/bin/sh
# Confined SELinux users, run at boot by bastion-confine-users.service.
#
#  - Every login except root (the "__default__" mapping) becomes staff_u
#    instead of unconfined_u, so SELinux policy applies to the user's programs.
#  - staff_exec_content / user_exec_content off: files in the home folder and
#    /tmp cannot be executed by confined users. Programs from the read-only
#    image (/usr) still run.
#
# Runs every boot but only changes what differs, so a manual change is undone.
# To opt out: sudo systemctl mask bastion-confine-users.service, then
#   sudo semanage login -m -s unconfined_u -r s0-s0:c0.c1023 __default__
set -eu

WANT_USER=staff_u
RANGE=s0-s0:c0.c1023

CURRENT=$(semanage login -l | awk '$1 == "__default__" { print $2 }')
if [ "$CURRENT" != "$WANT_USER" ]; then
    echo "Mapping __default__ logins: $CURRENT -> $WANT_USER"
    semanage login -m -s "$WANT_USER" -r "$RANGE" __default__
fi

for BOOL in staff_exec_content user_exec_content; do
    if getsebool "$BOOL" 2> /dev/null | grep -q -- '--> on$'; then
        echo "Setting $BOOL off"
        setsebool -P "$BOOL" off
    fi
done

echo "Confined users: __default__ -> $WANT_USER; exec from home and /tmp denied."
