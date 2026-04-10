#!/bin/bash
#
# OrbitOS — Post-package-install customization
#
# This script runs inside the airootfs chroot AFTER packages are installed
# by mkarchiso. It applies OrbitOS Calamares config overrides that would
# otherwise conflict with cachyos-calamares package files.
#

set -euo pipefail

OVERRIDES="/usr/local/lib/orbitos/calamares-overrides"

echo ":: Applying OrbitOS Calamares configuration overrides..."

# Override pacman.conf with OrbitOS version (includes CachyOS repos)
if [[ -f "$OVERRIDES/pacman.conf" ]]; then
    cp -f "$OVERRIDES/pacman.conf" /etc/pacman.conf
fi

# Override settings.conf
if [[ -f "$OVERRIDES/settings.conf" ]]; then
    cp -f "$OVERRIDES/settings.conf" /etc/calamares/settings.conf
fi

# Override module configs
if [[ -d "$OVERRIDES/modules" ]]; then
    cp -f "$OVERRIDES/modules/"*.conf /etc/calamares/modules/ 2>/dev/null || true
fi

# Install OrbitOS branding
if [[ -d "$OVERRIDES/branding/orbitos" ]]; then
    mkdir -p /etc/calamares/branding/orbitos
    cp -rf "$OVERRIDES/branding/orbitos/"* /etc/calamares/branding/orbitos/
fi

# Ensure archiso hooks are in mkinitcpio drop-in
# mkarchiso rebuilds initramfs after this script runs
echo ":: Configuring mkinitcpio with archiso hooks..."
mkdir -p /etc/mkinitcpio.conf.d
cat > /etc/mkinitcpio.conf.d/archiso.conf << 'MKINIT'
HOOKS=(base udev microcode modconf kms memdisk archiso archiso_loop_mnt block filesystems keyboard)
COMPRESSION="xz"
COMPRESSION_OPTIONS=(-9e)
MKINIT

# Enable services for the live session
systemctl enable NetworkManager.service 2>/dev/null || true
systemctl enable sddm.service 2>/dev/null || true
systemctl enable bluetooth.service 2>/dev/null || true

# Set locale
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

echo ":: OrbitOS customization complete."
