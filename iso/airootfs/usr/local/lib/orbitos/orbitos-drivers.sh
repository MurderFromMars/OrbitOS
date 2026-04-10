#!/bin/bash
#
# OrbitOS — Hardware driver detection via chwd
#
# Runs inside chroot (Calamares dontChroot: false).
#

set -euo pipefail
exec > >(tee -a /tmp/orbitos-drivers.log) 2>&1

echo ":: Installing hardware drivers..."

# ── Verify kernel state ─────────────────────────────────────────────────────

stray=$(pacman -Qqs '^linux-cachyos' 2>/dev/null || true)
if [[ -n "$stray" ]]; then
    echo ":: Removing unexpected CachyOS kernels: $stray"
    pacman -Rdd --noconfirm $stray 2>/dev/null || true
fi

pacman -S --noconfirm --needed linux-zen linux-zen-headers

# ── Install and run chwd ────────────────────────────────────────────────────

echo ":: Installing chwd hardware detector..."
pacman -S --noconfirm --needed chwd 2>/dev/null \
    || { echo ":: Warning: chwd install failed — install drivers manually."; exit 0; }

echo ":: Running hardware auto-detection..."
chwd -a -f 2>/dev/null \
    || { echo ":: Warning: chwd auto-detection failed — install drivers manually."; exit 0; }

echo ":: Hardware drivers installed via chwd."

# ── NVIDIA-specific GRUB parameters ────────────────────────────────────────

if [[ -f /etc/mkinitcpio.conf.d/10-chwd.conf ]] \
   && grep -q 'nvidia' /etc/mkinitcpio.conf.d/10-chwd.conf 2>/dev/null; then
    echo ":: NVIDIA detected — patching GRUB kernel parameters..."

    cmdline=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub \
        | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT="//;s/"$//')

    extra=""
    [[ "$cmdline" != *"nvidia_drm.modeset=1"* ]] && extra+=" nvidia_drm.modeset=1"
    [[ "$cmdline" != *"nvidia_drm.fbdev=1"* ]]   && extra+=" nvidia_drm.fbdev=1"

    if [[ -n "$extra" ]]; then
        sed -i \
            "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1${extra}\"|" \
            /etc/default/grub
    fi

    grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
    echo ":: NVIDIA kernel parameters applied."
fi

# ── Rebuild initramfs ──────────────────────────────────────────────────────

mkinitcpio -P
echo ":: Initramfs rebuilt."

# ── Swap setup (zram by default) ───────────────────────────────────────────

echo ":: Configuring zram swap..."
pacman -S --noconfirm --needed zram-generator 2>/dev/null || true

cat > /etc/systemd/zram-generator.conf << 'EOF'
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
EOF

echo ":: Driver and hardware setup complete."
