#!/bin/bash
#
# OrbitOS ISO Build Script
#
# Wraps mkarchiso to produce a bootable OrbitOS live ISO with
# Calamares installer and KDE Plasma desktop.
#
# Usage:
#   sudo ./build.sh              — build the ISO
#   sudo ./build.sh clean        — remove build artifacts and rebuild
#
# Requirements:
#   - Arch Linux host (or compatible)
#   - archiso package installed
#   - Chaotic-AUR repo configured (for calamares and gaming packages)
#   - ~15GB free disk space
#   - Internet connection
#

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="${SCRIPT_DIR}/work"
OUT_DIR="${SCRIPT_DIR}/out"

# ── Colors ───────────────────────────────────────────────────────────────────
_b=$'\033[1;34m'
_c=$'\033[1;36m'
_g=$'\033[1;32m'
_r=$'\033[1;31m'
_y=$'\033[1;33m'
_0=$'\033[0m'

info()  { printf "${_c}:: %s${_0}\n" "$1"; }
ok()    { printf "${_g}>> %s${_0}\n" "$1"; }
warn()  { printf "${_y}!! %s${_0}\n" "$1"; }
err()   { printf "${_r}XX %s${_0}\n" "$1"; }

# ── Preflight ────────────────────────────────────────────────────────────────

[[ $EUID -eq 0 ]] || { err "Must be run as root: sudo ./build.sh"; exit 1; }

command -v mkarchiso &>/dev/null || {
    err "archiso is not installed. Run: sudo pacman -S archiso"
    exit 1
}

# ── Clean mode ───────────────────────────────────────────────────────────────

if [[ "${1:-}" == "clean" ]]; then
    info "Cleaning previous build artifacts..."
    rm -rf "$WORK_DIR"
    rm -rf "$OUT_DIR"
    ok "Clean complete."
fi

# ── Ensure Chaotic-AUR keys are set up on the build host ────────────────────

if ! pacman-key --list-keys 3056513887B78AEB &>/dev/null 2>&1; then
    info "Setting up Chaotic-AUR keyring on build host..."
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
    pacman-key --lsign-key 3056513887B78AEB
    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
        pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' \
            >> /etc/pacman.conf
        pacman -Sy --noconfirm
    fi
    ok "Chaotic-AUR configured on build host."
fi

# ── Copy the OrbitOS logo into branding if it exists ────────────────────────

LOGO_SRC="${SCRIPT_DIR}/../ps4.png"
LOGO_DST="${SCRIPT_DIR}/airootfs/etc/calamares/branding/orbitos/orbitos-logo.png"
PIXMAP_DST="${SCRIPT_DIR}/airootfs/usr/share/pixmaps/orbitos.png"

if [[ -f "$LOGO_SRC" ]]; then
    mkdir -p "$(dirname "$LOGO_DST")" "$(dirname "$PIXMAP_DST")"
    cp "$LOGO_SRC" "$LOGO_DST"
    cp "$LOGO_SRC" "$PIXMAP_DST"
    info "OrbitOS logo copied into ISO."
else
    warn "ps4.png not found at repo root — branding will use placeholder."
fi

# ── Build ────────────────────────────────────────────────────────────────────

info "Building OrbitOS ISO..."
printf "${_b}  Profile:  %s${_0}\n" "$SCRIPT_DIR"
printf "${_b}  Work dir: %s${_0}\n" "$WORK_DIR"
printf "${_b}  Output:   %s${_0}\n" "$OUT_DIR"
echo ""

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$SCRIPT_DIR"

echo ""
ok "OrbitOS ISO built successfully!"
echo ""
printf "${_c}  Output: %s${_0}\n" "$(ls -1 "$OUT_DIR"/*.iso 2>/dev/null | tail -1)"
printf "${_c}  Size:   %s${_0}\n" "$(du -sh "$OUT_DIR"/*.iso 2>/dev/null | cut -f1 | tail -1)"
echo ""
info "Write to USB: sudo dd bs=4M if=out/orbitos-*.iso of=/dev/sdX status=progress oflag=sync"
info "Or use: sudo cp out/orbitos-*.iso /dev/sdX  (for Ventoy-compatible drives)"
