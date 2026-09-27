#!/usr/bin/env bash
# Build-time part of the confined-users setup. The runtime part is
# /usr/libexec/bastion/confine-users.sh, run by bastion-confine-users.service.
set -euo pipefail

chmod 755 /usr/libexec/bastion/confine-users.sh
