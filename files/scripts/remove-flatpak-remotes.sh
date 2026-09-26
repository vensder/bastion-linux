#!/usr/bin/env bash
# No Flatpak remotes: every app comes from the signed image, one update channel.
set -euo pipefail

for dir in /etc/flatpak/remotes.d /usr/share/flatpak/remotes.d; do
    if [ -d "$dir" ]; then
        find "$dir" -name '*.flatpakrepo' -print -delete
    fi
done

# Remotes already configured in the image's /var (normally none).
if command -v flatpak > /dev/null; then
    for remote in $(flatpak remotes --system --columns=name 2> /dev/null); do
        flatpak remote-delete --system --force "$remote"
    done
fi
