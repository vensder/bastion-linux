#!/usr/bin/env bash
# Build-time part of the confined-users setup (runtime part:
# /usr/libexec/bastion/confine-users.sh via bastion-confine-users.service).
set -euo pipefail

chmod 755 /usr/libexec/bastion/confine-users.sh

# staff_u users need an explicit SELinux role for sudo; without it, root via
# sudo would stay in the confined staff_t domain and admin tasks (bootc
# upgrade) would fail. sysadm_r is SELinux's administrator role.
SUDOERS=/etc/sudoers.d/bastion-sysadm
cat > "$SUDOERS" <<'EOF'
# Bastion: confined admins (staff_u) get the SELinux admin role through sudo.
%wheel ALL=(ALL) TYPE=sysadm_t ROLE=sysadm_r ALL
EOF
chmod 440 "$SUDOERS"
visudo -cf "$SUDOERS"
