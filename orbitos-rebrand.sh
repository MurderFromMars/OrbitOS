#!/bin/bash
#
#  OrbitOS Rebrand — run on existing systems to restore branding
#  and install the pacman hook so it sticks.
#

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Run as root: sudo $0"
    exit 1
fi

echo "[OrbitOS] Writing /etc/os-release ..."
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

echo "[OrbitOS] Writing /etc/lsb-release ..."
cat > /etc/lsb-release << 'EOF'
DISTRIB_ID="OrbitOS"
DISTRIB_RELEASE="rolling"
DISTRIB_DESCRIPTION="OrbitOS"
EOF

echo "[OrbitOS] Installing branding restore script ..."
mkdir -p /usr/local/bin
cat > /usr/local/bin/orbitos-branding << 'BRANDEOF'
#!/bin/bash
cat > /etc/os-release << 'OSEOF'
NAME="OrbitOS"
PRETTY_NAME="OrbitOS"
ID=arch
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://github.com/MurderFromMars"
LOGO=orbitos
OSEOF

cp /etc/os-release /usr/lib/os-release 2>/dev/null || true

cat > /etc/lsb-release << 'LSBEOF'
DISTRIB_ID="OrbitOS"
DISTRIB_RELEASE="rolling"
DISTRIB_DESCRIPTION="OrbitOS"
LSBEOF
BRANDEOF
chmod +x /usr/local/bin/orbitos-branding

echo "[OrbitOS] Installing pacman hook ..."
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/orbitos-branding.hook << 'HOOKEOF'
[Trigger]
Type = Package
Operation = Install
Operation = Upgrade
Target = filesystem
Target = lsb-release

[Action]
Description = Restoring OrbitOS branding...
When = PostTransaction
Exec = /usr/local/bin/orbitos-branding
HOOKEOF

echo "[OrbitOS] Done — branding restored and pacman hook installed."
