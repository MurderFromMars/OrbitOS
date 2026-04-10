#!/usr/bin/env bash
#
# OrbitOS archiso profile definition
#

iso_name="orbitos"
iso_label="ORBITOS_$(date +%Y%m)"
iso_publisher="OrbitOS <https://github.com/MurderFromMars/OrbitOS>"
iso_application="OrbitOS Live/Installer"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=(
    'bios.syslinux.mbr'
    'bios.syslinux.eltorito'
    'uefi-ia32.grub.esp'
    'uefi-x64.grub.esp'
    'uefi-ia32.grub.eltorito'
    'uefi-x64.grub.eltorito'
)
script="customize_airootfs.sh"
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '-19')
file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:400"
    ["/usr/local/lib/orbitos"]="0:0:755"
    ["/usr/local/lib/orbitos/orbitos-pacstrap.sh"]="0:0:755"
    ["/usr/local/lib/orbitos/orbitos-repos.sh"]="0:0:755"
    ["/usr/local/lib/orbitos/orbitos-desktop.sh"]="0:0:755"
    ["/usr/local/lib/orbitos/orbitos-extras.sh"]="0:0:755"
    ["/usr/local/lib/orbitos/orbitos-drivers.sh"]="0:0:755"
    ["/usr/local/lib/orbitos/orbitos-installer.sh"]="0:0:755"
    ["/usr/local/lib/orbitos/orbitos-live-setup.sh"]="0:0:755"
    ["/root/customize_airootfs.sh"]="0:0:755"
)
