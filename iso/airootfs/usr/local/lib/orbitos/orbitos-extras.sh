#!/bin/bash
#
# OrbitOS — Branding, CyberXero Toolkit, PS4 Theme, Handheld setup
#
# Runs inside chroot (Calamares dontChroot: false).
# Calamares sets up the user account before this runs.
#

set -euo pipefail
exec > >(tee -a /tmp/orbitos-extras.log) 2>&1

ORBIT_LOGO_URL="https://raw.githubusercontent.com/MurderFromMars/OrbitOS/main/ps4.png"

# Find the created user (first non-root user with UID >= 1000)
USERNAME=$(awk -F: '$3 >= 1000 && $3 < 65534 { print $1; exit }' /etc/passwd)
[[ -z "$USERNAME" ]] && { echo ":: Warning: no user found, skipping user-specific setup"; USERNAME=""; }

# ══════════════════════════════════════════════════════════════════════════════
# DISTRO BRANDING
# ══════════════════════════════════════════════════════════════════════════════

echo ":: Applying OrbitOS branding..."

# os-release
cat > /etc/os-release << 'EOF'
NAME="OrbitOS"
PRETTY_NAME="OrbitOS"
ID=arch
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://github.com/MurderFromMars"
LOGO=orbitos
EOF
cp /etc/os-release /usr/lib/os-release 2>/dev/null || true

cat > /etc/lsb-release << 'EOF'
DISTRIB_ID="OrbitOS"
DISTRIB_RELEASE="rolling"
DISTRIB_DESCRIPTION="OrbitOS"
EOF

# Logo
local_icon_dir="/usr/share/icons/hicolor"
mkdir -p "$local_icon_dir/scalable/apps" /usr/share/pixmaps

logo_installed="no"
if curl -fsSL "$ORBIT_LOGO_URL" -o /usr/share/pixmaps/orbitos.png 2>/dev/null; then
    for size in 64 128 256; do
        mkdir -p "$local_icon_dir/${size}x${size}/apps"
        cp /usr/share/pixmaps/orbitos.png \
           "$local_icon_dir/${size}x${size}/apps/orbitos.png"
    done
    logo_installed="yes"
    echo ":: Logo downloaded and installed."
fi

if [[ "$logo_installed" == "no" ]]; then
    cat > "$local_icon_dir/scalable/apps/orbitos.svg" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <rect width="256" height="256" rx="32" fill="#0d1117"/>
  <ellipse cx="128" cy="128" rx="88" ry="88"
           fill="none" stroke="#17d4e8" stroke-width="8" stroke-dasharray="20 10"/>
  <circle cx="128" cy="128" r="36" fill="#17d4e8"/>
  <text x="128" y="228" font-family="sans-serif" font-size="28" font-weight="bold"
        fill="#ffffff" text-anchor="middle" letter-spacing="4">ORBIT</text>
</svg>
SVGEOF
    cp "$local_icon_dir/scalable/apps/orbitos.svg" /usr/share/pixmaps/orbitos.svg
    echo ":: SVG placeholder logo installed."
fi

gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true

# KDE About panel
pacman -S --noconfirm --needed kcm-about-distroinfo 2>/dev/null || true

local_logo_path="/usr/share/pixmaps/orbitos.png"
[[ "$logo_installed" == "no" ]] && local_logo_path="/usr/share/icons/hicolor/scalable/apps/orbitos.svg"

mkdir -p /etc/xdg
cat > /etc/xdg/kcm-about-distrorc << EOF
[General]
LogoPath=$local_logo_path
Name=OrbitOS
Website=https://github.com/MurderFromMars
EOF

# GRUB branding
if [[ -f /etc/default/grub ]]; then
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="OrbitOS"/' /etc/default/grub
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 nvme_load=yes"/' /etc/default/grub
    sed -i 's/^#*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub
fi

echo ":: Branding applied."

# ══════════════════════════════════════════════════════════════════════════════
# CYBERXERO TOOLKIT
# ══════════════════════════════════════════════════════════════════════════════

if [[ -n "$USERNAME" ]]; then
    echo ":: Installing CyberXero Toolkit build dependencies..."
    pacman -S --noconfirm --needed \
        rust cargo pkgconf \
        gtk4 glib2 libadwaita vte4 \
        polkit \
        cmake extra-cmake-modules \
        kitty cava imagemagick \
        scx-scheds 2>/dev/null \
        || echo ":: Warning: some build deps failed"

    echo ":: Building CyberXero Toolkit..."
    toolkit_built="no"
    su -l "$USERNAME" -c "
        set -e
        cd \$HOME
        command -v rustup &>/dev/null && rustup default stable 2>/dev/null || true
        git clone https://github.com/MurderFromMars/CyberXero-Toolkit CyberXero-Toolkit 2>&1 | tail -3
        cd CyberXero-Toolkit
        cargo build --release 2>&1 | grep -E '^(error|Compiling|Finished)' | tail -20
    " && toolkit_built="yes" \
      || echo ":: Warning: Toolkit build failed — re-run ~/CyberXero-Toolkit/install.sh after reboot."

    if [[ "$toolkit_built" == "yes" ]]; then
        echo ":: Installing toolkit binaries..."
        SRC="/home/$USERNAME/CyberXero-Toolkit"
        mkdir -p /opt/xero-toolkit/sources/scripts /opt/xero-toolkit/sources/systemd

        install -Dm755 "$SRC/target/release/xero-toolkit" /opt/xero-toolkit/xero-toolkit
        install -Dm755 "$SRC/target/release/xero-authd"   /opt/xero-toolkit/xero-authd   2>/dev/null || true
        install -Dm755 "$SRC/target/release/xero-auth"    /opt/xero-toolkit/xero-auth    2>/dev/null || true

        [[ -d "$SRC/sources/scripts" ]] && install -m755 "$SRC/sources/scripts/"* /opt/xero-toolkit/sources/scripts/ 2>/dev/null || true
        [[ -d "$SRC/sources/systemd" ]] && install -m644 "$SRC/sources/systemd/"* /opt/xero-toolkit/sources/systemd/ 2>/dev/null || true

        ln -sf /opt/xero-toolkit/xero-toolkit /usr/bin/xero-toolkit

        install -Dm644 "$SRC/packaging/xero-toolkit.desktop" \
            /usr/share/applications/xero-toolkit.desktop 2>/dev/null || true
        install -Dm644 "$SRC/gui/resources/icons/scalable/apps/xero-toolkit.png" \
            /usr/share/icons/hicolor/scalable/apps/xero-toolkit.png 2>/dev/null || true
        gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true

        if [[ -d "$SRC/extra-scripts/usr/local/bin" ]]; then
            for s in "$SRC/extra-scripts/usr/local/bin/"*; do
                [[ -f "$s" ]] && install -Dm755 "$s" "/usr/local/bin/$(basename "$s")"
            done
        fi

        rm -rf "$SRC/target"
        echo ":: CyberXero Toolkit installed."
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# PS4 PLASMA THEME — first-boot autostart
# ══════════════════════════════════════════════════════════════════════════════

if [[ -n "$USERNAME" ]]; then
    echo ":: Setting up PS4 Plasma Theme first-boot autostart..."

    autostart="/home/$USERNAME/.config/autostart"
    mkdir -p "$autostart"

    cat > "$autostart/orbitos-ps4-theme.sh" << 'FIRSTBOOT'
#!/usr/bin/env bash

SELF_SCRIPT="$HOME/.config/autostart/orbitos-ps4-theme.sh"
SELF_DESKTOP="$HOME/.config/autostart/orbitos-ps4-theme.desktop"
REPO_DIR="$HOME/Playstation-4-Plasma"
HANDHELD_MARKER="$HOME/.config/orbitos-handheld"

log()  { printf "\033[1;36m[OrbitOS]\033[0m %s\n" "$1"; }
ok()   { printf "\033[1;32m[  OK   ]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[  !!   ]\033[0m %s\n" "$1"; }
err()  { printf "\033[1;31m[ FAIL  ]\033[0m %s\n" "$1"; }

if [[ -z "$ORBITOS_RUNNING" ]]; then
    export ORBITOS_RUNNING=1
    if   command -v konsole &>/dev/null; then konsole --hold -e bash "$SELF_SCRIPT"
    elif command -v kitty   &>/dev/null; then kitty bash "$SELF_SCRIPT"
    elif command -v xterm   &>/dev/null; then xterm -hold -e bash "$SELF_SCRIPT"
    else bash "$SELF_SCRIPT"
    fi
    exit 0
fi

printf "\n\033[1;35m╔══════════════════════════════════════════════════════╗\033[0m\n"
printf   "\033[1;35m║   OrbitOS — First-Boot Setup                         ║\033[0m\n"
printf   "\033[1;35m╚══════════════════════════════════════════════════════╝\033[0m\n\n"

if [[ -d "$REPO_DIR/.git" ]]; then
    log "Updating existing repository..."
    git -C "$REPO_DIR" pull --rebase &>/dev/null && ok "Repository updated" \
        || warn "Could not update — proceeding with existing copy"
else
    log "Cloning Playstation-4-Plasma repository..."
    if git clone https://github.com/MurderFromMars/Playstation-4-Plasma "$REPO_DIR"; then
        ok "Repository cloned"
    else
        err "Failed to clone — check your internet connection."
        echo "  Retry later:  bash ~/.config/autostart/orbitos-ps4-theme.sh"
        sleep 15; exit 1
    fi
fi

log "Running PS4 Plasma theme installer..."
if bash "$REPO_DIR/install.sh"; then
    ok "PS4 Plasma Theme applied!"
else
    warn "Installer finished with errors — some elements may be missing."
    warn "Re-run manually:  bash ~/Playstation-4-Plasma/install.sh"
fi

if pacman -Qq cachyos-handheld 2>/dev/null | grep -q .; then
    log "Creating 'Return to Gaming Mode' desktop shortcut..."
    mkdir -p "$HOME/Desktop"
    cat > "$HOME/Desktop/Return to Gaming Mode.desktop" << 'RTGM'
[Desktop Entry]
Name=Return to Gaming Mode
Comment=Log out of Desktop Mode and return to Gaming Mode
Exec=qdbus6 org.kde.Shutdown /Shutdown org.kde.Shutdown.logout
Icon=orbitos
Terminal=false
Type=Application
Categories=Game;
StartupNotify=false
RTGM
    chmod +x "$HOME/Desktop/Return to Gaming Mode.desktop"
    gio set "$HOME/Desktop/Return to Gaming Mode.desktop" \
        metadata::trusted true 2>/dev/null || true
    ok "'Return to Gaming Mode' shortcut placed on desktop"
fi

if [[ -f "$HANDHELD_MARKER" ]]; then
    echo ""
    printf "\033[1;35m── Handheld Mode: Bazzite Kernel ──\033[0m\n\n"
    AUR_HELPER=""
    if   command -v paru &>/dev/null; then AUR_HELPER="paru"
    elif command -v yay  &>/dev/null; then AUR_HELPER="yay"
    fi
    if [[ -z "$AUR_HELPER" ]]; then
        err "No AUR helper found — cannot install linux-bazzite-bin."
        warn "Install manually: paru -S linux-bazzite-bin"
    else
        log "Building linux-bazzite-bin via $AUR_HELPER (this may take a while)..."
        if $AUR_HELPER -S --noconfirm --needed linux-bazzite-bin; then
            ok "linux-bazzite-bin installed"
            log "Removing linux-zen..."
            sudo pacman -Rdd --noconfirm linux-zen linux-zen-headers 2>/dev/null \
                && ok "linux-zen removed" \
                || warn "linux-zen removal had errors"
            rm -f "$HANDHELD_MARKER"
            ok "Handheld kernel swap complete!"
            echo ""
            warn "A reboot is required to boot into the Bazzite kernel."
            warn "Run: sudo reboot"
        else
            err "linux-bazzite-bin build failed."
            warn "Retry manually: $AUR_HELPER -S linux-bazzite-bin"
        fi
    fi
    echo ""
fi

rm -f "$SELF_DESKTOP" "$SELF_SCRIPT"
ok "First-boot setup complete."
[[ -f "$HANDHELD_MARKER" ]] || log "Closing in 10 seconds."
sleep 10
FIRSTBOOT

    chmod +x "$autostart/orbitos-ps4-theme.sh"

    cat > "$autostart/orbitos-ps4-theme.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=OrbitOS First-Boot Setup
Comment=Applies PS4 theme + handheld kernel swap on first login (runs once, then removes itself)
Exec=bash /home/$USERNAME/.config/autostart/orbitos-ps4-theme.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
X-KDE-StartupNotify=false
DESKTOP

    chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config/autostart" 2>/dev/null || true

    # fastfetch in bashrc
    local_bashrc="/home/$USERNAME/.bashrc"
    if ! grep -qF "fastfetch" "$local_bashrc" 2>/dev/null; then
        printf '\n# OrbitOS: system info on terminal open\nfastfetch\n' >> "$local_bashrc"
    fi
    chown "$USERNAME:$USERNAME" "$local_bashrc" 2>/dev/null || true

    # XDG user dirs
    su -l "$USERNAME" -c "xdg-user-dirs-update" 2>/dev/null || true

    echo ":: PS4 Theme first-boot autostart configured."
fi

# ══════════════════════════════════════════════════════════════════════════════
# HANDHELD MODE (if marker file exists — set by Calamares via global storage)
# ══════════════════════════════════════════════════════════════════════════════

# Check if handheld mode was requested via the config marker
HANDHELD_CONFIG="/tmp/orbitos-handheld-enabled"
if [[ -f "$HANDHELD_CONFIG" && -n "$USERNAME" ]]; then
    echo ":: Setting up handheld mode..."

    # Create handheld marker for first-boot kernel swap
    marker="/home/$USERNAME/.config/orbitos-handheld"
    mkdir -p "$(dirname "$marker")"
    echo "pending" > "$marker"
    chown "$USERNAME:$USERNAME" "$marker" 2>/dev/null || true

    # Install HHD
    pacman -S --noconfirm --needed hhd hhd-ui 2>/dev/null \
        || echo ":: Warning: HHD install failed"

    # Mask conflicting services
    systemctl mask inputplumber 2>/dev/null || true
    systemctl mask steamos-manager 2>/dev/null || true

    # Enable HHD
    systemctl enable "hhd@$USERNAME" 2>/dev/null \
        || echo ":: Warning: could not enable hhd"

    echo ":: Handheld mode configured (bazzite kernel installs on first login)."
fi

echo ":: OrbitOS extras installation complete."
