#!/bin/bash
#
# OrbitOS live environment setup — runs once on live desktop boot.
# Enables services, sets up repos, marks desktop shortcuts trusted.
#

set -euo pipefail

# Enable NetworkManager in live session
systemctl start NetworkManager 2>/dev/null || true
systemctl start bluetooth 2>/dev/null || true

# Trust desktop shortcuts so Plasma doesn't show warnings
for f in ~/Desktop/*.desktop; do
    [[ -f "$f" ]] && gio set "$f" metadata::trusted true 2>/dev/null || true
done

# Set up Chaotic-AUR keys if not already done (needed for calamares package installs)
if ! pacman-key --list-keys 3056513887B78AEB &>/dev/null; then
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>/dev/null || true
    pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
fi

exit 0
