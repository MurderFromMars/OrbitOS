#!/bin/bash
#
# OrbitOS — Pacstrap helper for Calamares
#
# Usage:
#   orbitos-pacstrap.sh prepare        — set up live-env repos
#   orbitos-pacstrap.sh install <root> — pacstrap base packages into <root>
#

set -euo pipefail
exec > >(tee -a /tmp/orbitos-pacstrap.log) 2>&1

ACTION="${1:-}"
TARGET="${2:-}"

# ══════════════════════════════════════════════════════════════════════════════
# PREPARE — set up repos in the live environment for pacstrap
# ══════════════════════════════════════════════════════════════════════════════

do_prepare() {
    echo ":: Preparing live environment repositories..."

    # Enable multilib
    sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/[multilib]\nInclude/}' \
        /etc/pacman.conf

    # Add Chaotic-AUR if missing
    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        pacman-key --lsign-key 3056513887B78AEB
        pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
        pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' \
            >> /etc/pacman.conf
    fi

    # Set parallel downloads
    if grep -q '^#*ParallelDownloads' /etc/pacman.conf; then
        sed -i 's/^#*ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
    fi

    pacman -Sy --noconfirm
    echo ":: Live environment prepared."
}

# ══════════════════════════════════════════════════════════════════════════════
# INSTALL — pacstrap base system into target
# ══════════════════════════════════════════════════════════════════════════════

do_install() {
    [[ -z "$TARGET" ]] && { echo "ERROR: no target mountpoint"; exit 1; }
    [[ -d "$TARGET" ]] || { echo "ERROR: '$TARGET' is not a directory"; exit 1; }

    echo ":: Installing base system to $TARGET ..."

    local pkgs="base base-devel linux-zen linux-zen-headers"

    # CPU microcode
    grep -q "GenuineIntel" /proc/cpuinfo && pkgs+=" intel-ucode"
    grep -q "AuthenticAMD" /proc/cpuinfo && pkgs+=" amd-ucode"

    # Bootloader + filesystem tools
    pkgs+=" grub efibootmgr os-prober"
    pkgs+=" btrfs-progs dosfstools e2fsprogs xfsprogs gptfdisk"

    # Core utilities
    pkgs+=" sudo nano vim git wget curl"

    # Networking
    pkgs+=" networkmanager iw iwd ppp openssh wpa_supplicant wireless_tools"
    pkgs+=" avahi nss-mdns dhcpcd"

    # Bluetooth
    pkgs+=" bluez bluez-libs bluez-utils"

    # Audio
    pkgs+=" pipewire wireplumber pipewire-jack pipewire-alsa pipewire-pulse"
    pkgs+=" alsa-utils alsa-plugins alsa-firmware"

    # Media codecs
    pkgs+=" gstreamer gst-libav gst-plugins-good gst-plugins-bad gst-plugin-pipewire"

    # Printing
    pkgs+=" cups"

    # Display
    pkgs+=" xorg-server xorg-xwayland xorg-xinit"

    # Firmware
    pkgs+=" fwupd sof-firmware linux-firmware"

    # Calamares needs these for post-install modules
    pkgs+=" mkinitcpio"

    pacstrap -K "$TARGET" $pkgs

    echo ":: Base system installed."
}

# ══════════════════════════════════════════════════════════════════════════════

case "$ACTION" in
    prepare) do_prepare ;;
    install) do_install ;;
    *)
        echo "Usage: $0 {prepare|install <target>}"
        exit 1
        ;;
esac
