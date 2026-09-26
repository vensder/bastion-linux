#!/usr/bin/env bash
# Lock /etc/containers/policy.json down after the BlueBuild signing module:
#  - trust every image under our GHCR namespace (e.g. ghcr.io/OWNER/*) with
#    the same cosign key, so machines can switch between variants verified;
#  - reject every other registry path (the template default accepts anything).
set -euo pipefail

POLICY=/etc/containers/policy.json

# The entry the signing module added for this image, e.g. ghcr.io/OWNER/bastion-linux.
OWN=$(jq -r '[.transports.docker | to_entries[]
              | select(.value[0].type == "sigstoreSigned") | .key][0] // empty' "$POLICY")
if [ -z "$OWN" ]; then
    echo "ERROR: no sigstoreSigned entry in $POLICY" >&2
    exit 1
fi
NS=${OWN%/*}

jq --arg own "$OWN" --arg ns "$NS" '
    .transports.docker[$ns] = .transports.docker[$own]
  | .transports.docker[""] = [{"type": "reject"}]
' "$POLICY" > "$POLICY.new"
mv "$POLICY.new" "$POLICY"

# Signatures are OCI attachments next to the image; enable that lookup for the
# whole namespace too (the signing module only does it for this image).
cat > /etc/containers/registries.d/bastion-namespace.yaml <<EOF
docker:
  ${NS}:
    use-sigstore-attachments: true
EOF

echo "container policy locked:"
jq -c '.transports.docker | to_entries[] | {key, type: .value[0].type}' "$POLICY"
