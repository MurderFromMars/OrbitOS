#!/bin/bash
#
# OrbitOS — Configure repositories in the target system
#
# Runs inside chroot (Calamares dontChroot: false).
# Adds: multilib, Chaotic-AUR, CachyOS repos.
#

set -euo pipefail
exec > >(tee -a /tmp/orbitos-repos.log) 2>&1

echo ":: Configuring repositories..."

# ── Helper ───────────────────────────────────────────────────────────────────

pacman_set_opts() {
    local conf="$1"
    local flags=(Color ILoveCandy VerbosePkgLists DisableDownloadTimeout)
    for flag in "${flags[@]}"; do
        if grep -q "^#\s*${flag}" "$conf"; then
            sed -i "s/^#\s*${flag}.*/${flag}/" "$conf"
        elif ! grep -q "^${flag}" "$conf"; then
            sed -i '/^\[options\]/a '"${flag}" "$conf"
        fi
    done
}

# ── Multilib ─────────────────────────────────────────────────────────────────

sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/[multilib]\nInclude/}' \
    /etc/pacman.conf

# ── Chaotic-AUR ──────────────────────────────────────────────────────────────

if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
    echo ":: Adding Chaotic-AUR..."
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
    pacman -U --noconfirm \
        'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' \
        >> /etc/pacman.conf
fi

# ── CachyOS ─────────────────────────────────────────────────────────────────

if ! grep -q "\[cachyos\]" /etc/pacman.conf; then
    echo ":: Adding CachyOS repository..."
    cd /tmp
    curl -sSL https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
    tar xf cachyos-repo.tar.xz
    cd cachyos-repo
    yes | ./cachyos-repo.sh || echo ":: Warning: cachyos-repo.sh reported errors"
    rm -rf /tmp/cachyos-repo /tmp/cachyos-repo.tar.xz
fi

# ── Pacman options ───────────────────────────────────────────────────────────

if grep -q '^#*ParallelDownloads' /etc/pacman.conf; then
    sed -i 's/^#*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
fi
pacman_set_opts /etc/pacman.conf

# ── Sync ─────────────────────────────────────────────────────────────────────

pacman -Syy --noconfirm

# Verify CachyOS is functional
if pacman -Si cachyos-gaming-meta &>/dev/null; then
    echo ":: CachyOS repository verified."
else
    echo ":: Warning: CachyOS packages not found — retrying sync..."
    pacman -Syy --noconfirm
    pacman -Si cachyos-gaming-meta &>/dev/null \
        && echo ":: CachyOS verified on retry." \
        || echo ":: Warning: CachyOS gaming meta unavailable — install manually after reboot."
fi

echo ":: Repository configuration complete."
