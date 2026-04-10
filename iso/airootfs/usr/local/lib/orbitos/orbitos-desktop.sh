#!/bin/bash
#
# OrbitOS — Install KDE Plasma desktop, gaming packages, and system extras
#
# Runs inside chroot (Calamares dontChroot: false).
#

set -euo pipefail
exec > >(tee -a /tmp/orbitos-desktop.log) 2>&1

echo ":: Installing KDE Plasma desktop..."

# ── Plasma desktop ──────────────────────────────────────────────────────────

pacman -S --noconfirm --needed \
    plasma-meta \
    egl-wayland

# ── KDE applications ────────────────────────────────────────────────────────

pacman -S --noconfirm --needed \
    dolphin dolphin-plugins \
    konsole \
    kate \
    spectacle \
    gwenview \
    ark \
    okular \
    kfind \
    kcalc \
    yakuake \
    filelight \
    sweeper \
    kwalletmanager \
    kdialog

# ── Thumbnails / previews ──────────────────────────────────────────────────

pacman -S --noconfirm --needed \
    tumbler ffmpegthumbnailer poppler-qt6 \
    kdegraphics-thumbnailers

# ── System utilities ────────────────────────────────────────────────────────

pacman -S --noconfirm --needed \
    gnome-disk-utility \
    gvfs gvfs-mtp gvfs-smb gvfs-afc udisks2 udiskie \
    xdg-utils xdg-user-dirs \
    flatpak \
    tuned-ppd \
    switcheroo-control \
    brightnessctl \
    ntfs-3g exfatprogs \
    p7zip unrar unzip zip \
    btop htop fastfetch \
    bash-completion \
    inxi pciutils usbutils \
    pacman-contrib \
    topgrade

# ── CachyOS extras (may fail if repo not configured) ───────────────────────

pacman -S --noconfirm --needed cachyos-settings grub-hook 2>/dev/null \
    || echo ":: Warning: cachyos-settings or grub-hook not available"

# ── Fonts ───────────────────────────────────────────────────────────────────

pacman -S --noconfirm --needed \
    ttf-hack-nerd ttf-jetbrains-mono-nerd \
    ttf-ubuntu-font-family adobe-source-sans-fonts \
    noto-fonts noto-fonts-emoji

# ── AUR helper ──────────────────────────────────────────────────────────────

pacman -S --noconfirm --needed paru 2>/dev/null \
    || echo ":: Warning: paru not available from repos — install manually"

# ── Login manager ──────────────────────────────────────────────────────────

pacman -S --noconfirm --needed sddm
systemctl enable sddm.service

# ── Gaming packages ─────────────────────────────────────────────────────────

echo ":: Installing gaming packages..."
pacman -S --noconfirm --needed \
    cachyos-gaming-meta cachyos-gaming-applications 2>/dev/null \
    || {
        echo ":: Gaming packages failed — retrying after db refresh..."
        pacman -Syy --noconfirm
        pacman -S --noconfirm --needed \
            cachyos-gaming-meta cachyos-gaming-applications 2>/dev/null \
            || echo ":: Warning: gaming packages unavailable — install after reboot"
    }

# ── Enable services ────────────────────────────────────────────────────────

systemctl enable \
    NetworkManager \
    avahi-daemon \
    cups.socket \
    bluetooth \
    tuned 2>/dev/null || true
systemctl enable tuned-ppd 2>/dev/null || true
systemctl enable switcheroo-control 2>/dev/null || true
systemctl enable wpa_supplicant 2>/dev/null || true

systemctl disable iwd 2>/dev/null || true
systemctl disable dhcpcd 2>/dev/null || true

# ── NetworkManager WiFi backend ────────────────────────────────────────────

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi-backend.conf << 'EOF'
[device]
wifi.backend=wpa_supplicant
EOF

echo ":: Desktop installation complete."
