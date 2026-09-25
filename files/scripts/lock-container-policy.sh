#!/usr/bin/env bash
# The BlueBuild signing template leaves docker:"" as insecureAcceptAnything,
# so any image that is not ours is accepted unverified. Flip that to reject.
set -euo pipefail

POLICY=/etc/containers/policy.json

# Refuse to lock down unless our own signed entry is already present,
# otherwise the machine could not verify its own updates.
jq -e '[.transports.docker[][] | select(.type == "sigstoreSigned")] | length > 0' \
    "$POLICY" > /dev/null || { echo "ERROR: no sigstoreSigned entry in $POLICY" >&2; exit 1; }

jq '.transports.docker[""] = [{"type": "reject"}]' "$POLICY" > "$POLICY.new"
mv "$POLICY.new" "$POLICY"

echo "container policy locked:"
jq -c '.transports.docker | to_entries[] | {key, type: .value[0].type}' "$POLICY"
