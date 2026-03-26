#!/bin/bash
#
# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║                                                                               ║
# ║                      ✨ OrbitOS Arch Installer - KDE ✨                       ║
# ║                                                                               ║
# ║                           Self-contained installer.                           ║
# ║                                                                               ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝
#
# OrbitOS: Minimal Arch Linux + KDE Plasma + CachyOS Gaming + CyberXero Toolkit + PS4 Theme
#

set -Eeuo pipefail

# ────────────────────────────────────────────────────────────────────────────────
# CONFIGURATION
# ────────────────────────────────────────────────────────────────────────────────

VERSION="1.0"
SCRIPT_NAME="OrbitOS KDE Installer"
MOUNTPOINT="/mnt"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

declare -A CONFIG
CONFIG[locale]="en_US.UTF-8"
CONFIG[keyboard]="us"
CONFIG[timezone]="UTC"
CONFIG[hostname]="orbitos"
CONFIG[username]=""
CONFIG[user_password]=""
CONFIG[root_password]=""
CONFIG[disk]=""
CONFIG[filesystem]="btrfs"
CONFIG[encrypt]="no"
CONFIG[encrypt_boot]="no"
CONFIG[encrypt_password]=""
CONFIG[swap]="zram"
CONFIG[swap_algo]="zstd"
CONFIG[parallel_downloads]="5"
CONFIG[uefi]="no"
CONFIG[boot_part]=""
CONFIG[root_part]=""
CONFIG[root_device]=""
CONFIG[partition_mode]="auto"
CONFIG[reuse_efi]="no"
CONFIG[aur_helper]="paru"
CONFIG[login_manager]="sddm"
CONFIG[cachyos_optimized]="no"

# User-selected extra packages (populated during menu)
EXTRA_PKGS=""

# ────────────────────────────────────────────────────────────────────────────────
# ERROR HANDLING
# ────────────────────────────────────────────────────────────────────────────────

have_gum() { command -v gum &>/dev/null; }

on_err() {
    local exit_code=$?
    local line_no=${1:-?}
    local cmd=${2:-?}
    if have_gum; then
        gum style --foreground 196 --bold --margin "1 2" \
            "❌ ERROR (exit=$exit_code) at line $line_no" "$cmd"
        echo ""
        gum input --placeholder "Press Enter to exit..."
    else
        echo -e "${RED}ERROR (exit=$exit_code) at line $line_no${NC}"
        echo -e "${RED}$cmd${NC}"
    fi
    exit "$exit_code"
}

trap 'on_err "$LINENO" "$BASH_COMMAND"' ERR

# ────────────────────────────────────────────────────────────────────────────────
# UTILITY / UI HELPERS
# ────────────────────────────────────────────────────────────────────────────────

show_header() {
    clear
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 70 --margin "1 2" --padding "1 2" \
        "✨ $SCRIPT_NAME v$VERSION ✨" \
        "" \
        "Arch Linux + KDE Plasma + Gaming + PS4 Theme + CyberXero Toolkit"
}

show_submenu_header() { gum style --foreground 212 --bold --margin "1 2" "$1"; }
show_info()    { gum style --foreground 81  --margin "0 2" "$1"; }
show_success() { gum style --foreground 82  "  ✓ $1"; }
show_error()   { gum style --foreground 196 "  ✗ $1"; }
show_warning() { gum style --foreground 214 "  ⚠ $1"; }
confirm_action() { gum confirm --affirmative "Yes" --negative "No" "$1"; }

run_step() {
    local title="$1"; shift
    show_info "$title"
    "$@"
    show_success "${title%...}"
}

# ────────────────────────────────────────────────────────────────────────────────
# PREFLIGHT
# ────────────────────────────────────────────────────────────────────────────────

check_root() {
    if [[ ${EUID:-0} -ne 0 ]]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        echo "Run: sudo bash $0"
        exit 1
    fi
}

check_uefi() {
    [[ -d /sys/firmware/efi/efivars ]] && CONFIG[uefi]="yes" || CONFIG[uefi]="no"
}

INTERNET_OK="no"
check_internet() {
    [[ "$INTERNET_OK" == "yes" ]] && return 0
    if ping -c 1 -W 3 archlinux.org &>/dev/null; then
        INTERNET_OK="yes"; return 0
    fi
    echo -e "${RED}Error: No internet connection${NC}"
    exit 1
}

check_arch_iso() {
    if [[ ! -f /etc/arch-release ]]; then
        echo -e "${RED}Error: Must be run from the Arch Linux live ISO${NC}"
        exit 1
    fi
}

ensure_dependencies() {
    local deps=()
    command -v gum       &>/dev/null || deps+=(gum)
    command -v parted    &>/dev/null || deps+=(parted)
    command -v arch-chroot &>/dev/null || deps+=(arch-install-scripts)
    command -v sgdisk    &>/dev/null || deps+=(gptfdisk)
    command -v mkfs.btrfs &>/dev/null || deps+=(btrfs-progs)
    command -v mkfs.fat  &>/dev/null || deps+=(dosfstools)
    command -v mkfs.ext4 &>/dev/null || deps+=(e2fsprogs)
    command -v cryptsetup &>/dev/null || deps+=(cryptsetup)
    if [[ ${#deps[@]} -gt 0 ]]; then
        echo -e "${CYAN}Installing dependencies: ${deps[*]}${NC}"
        pacman -Sy --noconfirm "${deps[@]}" &>/dev/null
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# MENU STEPS
# ────────────────────────────────────────────────────────────────────────────────

select_locales() {
    show_header
    show_submenu_header "🗺️  System Locales"
    echo ""
    show_info "Select your system locale"
    echo ""

    local locales=(
        "en_US.UTF-8" "en_GB.UTF-8" "de_DE.UTF-8" "fr_FR.UTF-8"
        "es_ES.UTF-8" "it_IT.UTF-8" "pt_BR.UTF-8" "pt_PT.UTF-8"
        "ru_RU.UTF-8" "ja_JP.UTF-8" "ko_KR.UTF-8" "zh_CN.UTF-8"
        "pl_PL.UTF-8" "nl_NL.UTF-8" "tr_TR.UTF-8" "sv_SE.UTF-8"
        "da_DK.UTF-8" "fi_FI.UTF-8" "nb_NO.UTF-8" "cs_CZ.UTF-8"
    )

    local locale_sel=""
    locale_sel=$(printf '%s\n' "${locales[@]}" | gum filter --placeholder "Search locale..." --height 12) || true
    [[ -n "$locale_sel" ]] && CONFIG[locale]="$locale_sel" && show_success "Locale: $locale_sel"

    echo ""
    show_info "Select keyboard layout"
    echo ""

    local keyboards=(
        "us" "uk" "de" "fr" "es" "it" "pt-latin9" "br-abnt2"
        "ru" "pl" "cz" "hu" "se" "no" "dk" "fi" "nl" "jp106"
        "dvorak" "colemak"
    )

    local kb_sel=""
    kb_sel=$(printf '%s\n' "${keyboards[@]}" | gum filter --placeholder "Search layout..." --height 12) || true
    if [[ -n "$kb_sel" ]]; then
        CONFIG[keyboard]="$kb_sel"
        loadkeys "$kb_sel" 2>/dev/null || true
        show_success "Keyboard: $kb_sel"
    fi
    sleep 0.5
}

select_partitioning_mode() {
    show_header
    show_submenu_header "💾 Disk Configuration"
    echo ""

    local mode_sel=""
    mode_sel=$(printf '%s\n' \
        "Auto    │ Wipe entire disk (Recommended)" \
        "Manual  │ Choose existing partitions (dual-boot)" \
        | gum choose --height 4 --header "Partitioning mode:") || true

    if [[ "$mode_sel" == "Manual"* ]]; then
        CONFIG[partition_mode]="manual"
        manual_partitioning
    else
        CONFIG[partition_mode]="auto"
        select_disk
    fi
}

manual_partitioning() {
    show_header
    show_submenu_header "💾 Manual Partitioning"
    echo ""
    gum style --foreground 226 --bold --margin "0 2" \
        "ℹ️  Assigned partitions will be formatted. Others untouched."
    echo ""
    gum style --foreground 245 --margin "0 2" \
        "$(lsblk -o NAME,SIZE,FSTYPE,LABEL,TYPE,MOUNTPOINT 2>/dev/null)"
    echo ""

    if confirm_action "Launch cfdisk to create/modify partitions first?"; then
        local disks=()
        while IFS= read -r line; do [[ -n "$line" ]] && disks+=("$line"); done \
            < <(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null \
                | { grep -E '^/dev/(sd|nvme|vd|mmcblk)' || true; } | sed 's/  */ /g')
        if [[ ${#disks[@]} -gt 0 ]]; then
            local disk_sel=""
            disk_sel=$(printf '%s\n' "${disks[@]}" | gum choose --height 10 \
                --header "Select disk for cfdisk:") || true
            if [[ -n "$disk_sel" ]]; then
                local target_disk; target_disk=$(echo "$disk_sel" | awk '{print $1}')
                cfdisk "$target_disk" || true
                partprobe "$target_disk" || true; udevadm settle
            fi
        fi
    fi

    local partitions=()
    while IFS= read -r line; do [[ -n "$line" ]] && partitions+=("$line"); done \
        < <(lsblk -lpno NAME,SIZE,FSTYPE,LABEL 2>/dev/null \
            | { grep -E '^/dev/(sd|nvme|vd|mmcblk)[^ ]*[0-9]' || true; } | sed 's/  */ /g')

    [[ ${#partitions[@]} -eq 0 ]] && { show_error "No partitions found."; gum input --placeholder "Press Enter..."; return; }

    # Boot partition
    echo ""
    [[ "${CONFIG[uefi]}" == "yes" ]] && show_info "Select EFI System Partition (ESP)" \
                                      || show_info "Select boot partition (or skip)"
    echo ""

    local boot_opts=("-- Skip (no separate boot partition) --")
    for p in "${partitions[@]}"; do boot_opts+=("$p"); done
    local boot_sel=""
    boot_sel=$(printf '%s\n' "${boot_opts[@]}" | gum choose --height 14 --header "Boot/EFI partition:") || true

    if [[ "$boot_sel" == "-- Skip"* ]]; then
        CONFIG[boot_part]=""; CONFIG[reuse_efi]="no"
    else
        CONFIG[boot_part]=$(echo "$boot_sel" | awk '{print $1}')
        show_success "Boot/EFI: ${CONFIG[boot_part]}"
        if [[ "${CONFIG[uefi]}" == "yes" ]]; then
            echo ""
            local efi_action=""
            efi_action=$(printf '%s\n' \
                "Format  │ Wipe and format as FAT32" \
                "Reuse   │ Mount without formatting (dual-boot)" \
                | gum choose --height 4 --header "EFI partition action:") || true
            [[ "$efi_action" == "Reuse"* ]] && CONFIG[reuse_efi]="yes" || CONFIG[reuse_efi]="no"
        fi
    fi

    # Root partition
    echo ""
    show_info "Select root partition"
    echo ""
    local root_sel=""
    root_sel=$(printf '%s\n' "${partitions[@]}" | gum choose --height 14 --header "Root (/) partition:") || true
    [[ -z "$root_sel" ]] && { show_error "No root partition selected."; return; }
    CONFIG[root_part]=$(echo "$root_sel" | awk '{print $1}')
    show_success "Root: ${CONFIG[root_part]}"

    local parent_disk
    parent_disk=$(lsblk -no PKNAME "${CONFIG[root_part]}" 2>/dev/null | head -1)
    CONFIG[disk]="${parent_disk:+/dev/$parent_disk}"
    [[ -z "${CONFIG[disk]}" ]] && CONFIG[disk]="${CONFIG[root_part]}"

    # Filesystem
    echo ""
    show_info "Select filesystem"
    echo ""
    local fs_sel=""
    fs_sel=$(printf '%s\n' \
        "btrfs    │ CoW with snapshots (Recommended)" \
        "ext4     │ Traditional, reliable" \
        "xfs      │ High-performance" \
        | gum choose --height 5 --header "Filesystem:") || true
    [[ -n "$fs_sel" ]] && CONFIG[filesystem]=$(echo "$fs_sel" | awk '{print $1}') && show_success "Filesystem: ${CONFIG[filesystem]}"

    # Encryption
    echo ""
    if confirm_action "Enable LUKS2 encryption on root partition?"; then
        CONFIG[encrypt]="yes"; CONFIG[encrypt_boot]="no"
        local enc1="" enc2=""
        enc1=$(gum input --password --placeholder "Encryption password" --width 50) || true
        enc2=$(gum input --password --placeholder "Confirm password" --width 50) || true
        if [[ "$enc1" == "$enc2" && -n "$enc1" ]]; then
            CONFIG[encrypt_password]="$enc1"; show_success "Encryption enabled"
        else
            show_error "Passwords don't match. Encryption disabled."
            CONFIG[encrypt]="no"; CONFIG[encrypt_password]=""
        fi
    else
        CONFIG[encrypt]="no"; CONFIG[encrypt_boot]="no"; CONFIG[encrypt_password]=""
    fi
    sleep 0.5
}

select_disk() {
    show_header
    show_submenu_header "💾 Disk Selection"
    echo ""
    gum style --foreground 196 --bold --margin "0 2" "⚠️  WARNING: Selected disk will be COMPLETELY ERASED!"
    echo ""

    local disks=()
    while IFS= read -r line; do [[ -n "$line" ]] && disks+=("$line"); done \
        < <(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null \
            | { grep -E '^/dev/(sd|nvme|vd|mmcblk)' || true; } | sed 's/  */ /g')

    [[ ${#disks[@]} -eq 0 ]] && { show_error "No suitable disks found!"; exit 1; }

    local disk_sel=""
    disk_sel=$(printf '%s\n' "${disks[@]}" | gum choose --height 10 --header "Target disk:") || true
    if [[ -n "$disk_sel" ]]; then
        CONFIG[disk]=$(echo "$disk_sel" | awk '{print $1}')
        show_success "Disk: ${CONFIG[disk]}"
        echo ""
        gum style --foreground 245 --margin "0 2" "$(lsblk "${CONFIG[disk]}" 2>/dev/null)"
    fi

    echo ""
    show_info "Select filesystem"
    echo ""
    local fs_sel=""
    fs_sel=$(printf '%s\n' \
        "btrfs    │ CoW with snapshots (Recommended)" \
        "ext4     │ Traditional, reliable" \
        "xfs      │ High-performance" \
        | gum choose --height 5 --header "Filesystem:") || true
    [[ -n "$fs_sel" ]] && CONFIG[filesystem]=$(echo "$fs_sel" | awk '{print $1}') && show_success "Filesystem: ${CONFIG[filesystem]}"

    echo ""
    show_info "Disk Encryption (LUKS2)"
    echo ""
    if confirm_action "Enable full disk encryption?"; then
        CONFIG[encrypt]="yes"
        local enc1="" enc2=""
        enc1=$(gum input --password --placeholder "Encryption password" --width 50) || true
        enc2=$(gum input --password --placeholder "Confirm password" --width 50) || true
        if [[ "$enc1" == "$enc2" && -n "$enc1" ]]; then
            CONFIG[encrypt_password]="$enc1"
            echo ""
            local enc_scope=""
            enc_scope=$(printf '%s\n' \
                "root      │ Encrypt root only (faster boot)" \
                "root+boot │ Encrypt root & boot (more secure)" \
                | gum choose --height 4 --header "Encryption scope:") || true
            [[ "$enc_scope" == "root+boot"* ]] && CONFIG[encrypt_boot]="yes" || CONFIG[encrypt_boot]="no"
            show_success "Encryption enabled"
        else
            show_error "Passwords don't match. Encryption disabled."
            CONFIG[encrypt]="no"; CONFIG[encrypt_boot]="no"; CONFIG[encrypt_password]=""
        fi
    else
        CONFIG[encrypt]="no"; CONFIG[encrypt_boot]="no"; CONFIG[encrypt_password]=""
    fi
    sleep 0.5
}

configure_swap() {
    show_header
    show_submenu_header "🔄 Swap Configuration"
    echo ""
    local swap_sel=""
    swap_sel=$(printf '%s\n' \
        "zram     │ Compressed RAM swap (Recommended)" \
        "file     │ Traditional swap file on disk" \
        "none     │ No swap" \
        | gum choose --height 5 --header "Swap type:") || true
    if [[ -n "$swap_sel" ]]; then
        CONFIG[swap]=$(echo "$swap_sel" | awk '{print $1}')
        show_success "Swap: ${CONFIG[swap]}"
        if [[ "${CONFIG[swap]}" == "zram" ]]; then
            echo ""
            local algo_sel=""
            algo_sel=$(printf '%s\n' \
                "zstd     │ Best compression (Recommended)" \
                "lz4      │ Fastest" \
                "lzo      │ Balanced" \
                | gum choose --height 5 --header "zram algorithm:") || true
            [[ -n "$algo_sel" ]] && CONFIG[swap_algo]=$(echo "$algo_sel" | awk '{print $1}') && show_success "Algorithm: ${CONFIG[swap_algo]}"
        fi
    fi
    sleep 0.5
}

configure_hostname() {
    show_header
    show_submenu_header "💻 Hostname"
    echo ""
    local hostname=""
    hostname=$(gum input --placeholder "orbitos" --value "${CONFIG[hostname]}" --width 40 --header "Hostname:") || true
    if [[ "$hostname" =~ ^[a-z][a-z0-9-]*$ && ${#hostname} -le 63 ]]; then
        CONFIG[hostname]="$hostname"
    else
        show_warning "Invalid hostname, using default: orbitos"
        CONFIG[hostname]="orbitos"
    fi
    show_success "Hostname: ${CONFIG[hostname]}"
    sleep 0.5
}

configure_authentication() {
    show_header
    show_submenu_header "👤 User Account"
    echo ""
    local username=""
    username=$(gum input --placeholder "username" --width 40 --header "Username (lowercase):") || true
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ || ${#username} -gt 32 || -z "$username" ]]; then
        show_warning "Invalid username. Using 'user'"
        username="user"
    fi
    CONFIG[username]="$username"
    show_success "Username: ${CONFIG[username]}"
    echo ""

    local pass1="" pass2=""
    pass1=$(gum input --password --placeholder "Password for $username" --width 50) || true
    pass2=$(gum input --password --placeholder "Confirm password" --width 50) || true
    if [[ "$pass1" == "$pass2" && -n "$pass1" ]]; then
        CONFIG[user_password]="$pass1"
        show_success "User password set"
    else
        show_error "Passwords don't match. Please retry."
        sleep 1; configure_authentication; return
    fi

    echo ""
    show_submenu_header "🔐 Root Password"
    echo ""
    if confirm_action "Use same password for root?"; then
        CONFIG[root_password]="${CONFIG[user_password]}"
        show_success "Root password: same as user"
    else
        local rp1="" rp2=""
        rp1=$(gum input --password --placeholder "Root password" --width 50) || true
        rp2=$(gum input --password --placeholder "Confirm root password" --width 50) || true
        if [[ "$rp1" == "$rp2" && -n "$rp1" ]]; then
            CONFIG[root_password]="$rp1"; show_success "Root password set"
        else
            show_warning "Mismatch — using user password for root."
            CONFIG[root_password]="${CONFIG[user_password]}"
        fi
    fi
    sleep 0.5
}

select_timezone() {
    show_header
    show_submenu_header "🕐 Timezone"
    echo ""
    local regions=""
    regions=$(find /usr/share/zoneinfo -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
              | grep -vE '^(\+|posix|right|zoneinfo)$' | sort) || true
    local region=""
    region=$(echo "$regions" | gum filter --placeholder "Search region..." --height 12 --header "Region:") || true
    if [[ -n "$region" ]]; then
        local cities=""
        cities=$(find "/usr/share/zoneinfo/$region" -type f -printf '%f\n' 2>/dev/null | sort) || true
        if [[ -n "$cities" ]]; then
            echo ""
            local city=""
            city=$(echo "$cities" | gum filter --placeholder "Search city..." --height 12 --header "City:") || true
            [[ -n "$city" ]] && CONFIG[timezone]="$region/$city" || CONFIG[timezone]="$region"
        else
            CONFIG[timezone]="$region"
        fi
        show_success "Timezone: ${CONFIG[timezone]}"
    fi
    sleep 0.5
}

configure_parallel_downloads() {
    show_header
    show_submenu_header "⚡ Parallel Downloads"
    echo ""
    local sel=""
    sel=$(printf '%s\n' \
        "3      │ Conservative" \
        "5      │ Default (recommended)" \
        "10     │ Fast" \
        "15     │ Maximum" \
        | gum choose --height 6 --header "Parallel downloads:") || true
    [[ -n "$sel" ]] && CONFIG[parallel_downloads]=$(echo "$sel" | awk '{print $1}') && show_success "Downloads: ${CONFIG[parallel_downloads]}"
    sleep 0.5
}

select_aur_helper() {
    show_header
    show_submenu_header "🔧 AUR Helper"
    echo ""
    local sel=""
    sel=$(printf '%s\n' \
        "paru   │ Rust-based, feature-rich (Recommended)" \
        "yay    │ Go-based, widely used" \
        | gum choose --height 4 --header "AUR helper:") || true
    [[ -n "$sel" ]] && CONFIG[aur_helper]=$(echo "$sel" | awk '{print $1}') && show_success "AUR helper: ${CONFIG[aur_helper]}"
    sleep 0.5
}

select_login_manager() {
    show_header
    show_submenu_header "🔐 Login Manager"
    echo ""
    local sel=""
    sel=$(printf '%s\n' \
        "sddm            │ Stable, widely used (Recommended)" \
        "plasma-login    │ New KDE-native manager" \
        | gum choose --height 4 --header "Login manager:") || true
    [[ -n "$sel" ]] && CONFIG[login_manager]=$(echo "$sel" | awk '{print $1}') && show_success "Login manager: ${CONFIG[login_manager]}"
    sleep 0.5
}

toggle_cachyos_optimized() {
    show_header
    show_submenu_header "⚡ CachyOS Optimized Packages"
    echo ""
    gum style --foreground 245 --margin "0 2" \
        "CachyOS provides core system packages (glibc, mesa, etc.)" \
        "rebuilt with x86-64-v3/v4 optimizations for modern CPUs." \
        "" \
        "This replaces standard Arch packages with faster builds" \
        "tuned for your CPU's instruction set (AVX2/AVX-512)." \
        "" \
        "Safe on any CPU from ~2013 onwards (Haswell+)." \
        "The installer auto-detects your CPU's capability level."
    echo ""
    if confirm_action "Enable CachyOS optimized packages?"; then
        CONFIG[cachyos_optimized]="yes"
        show_success "CachyOS optimized packages: enabled"
    else
        CONFIG[cachyos_optimized]="no"
        show_success "CachyOS optimized packages: disabled (vanilla Arch)"
    fi
    sleep 0.5
}

select_extra_packages() {
    show_header
    show_submenu_header "📦 Optional Packages"
    echo ""
    show_info "Select any extra packages to install (space to toggle, enter to confirm)"
    echo ""

    local options=(
        "firefox            Web Browser"
        "brave-bin          Brave Browser"
        "librewolf          Privacy Browser"
        "discord            Discord"
        "vesktop            Discord (enhanced)"
        "telegram-desktop   Telegram"
        "vscodium           VSCodium editor"
        "keepassxc          Password manager"
        "bitwarden          Password manager"
        "gimp               Image editor"
        "krita              Digital painting"
        "inkscape           Vector graphics"
        "mpv                Media player"
        "vlc                Media player"
        "easyeffects        Audio effects"
        "kdenlive           Video editor"
        "libreoffice-fresh  Office suite"
        "thunderbird        Email client"
        "nextcloud-client   Nextcloud sync"
        "obsidian           Note-taking"
    )

    # Build display list and package map
    local display_list=()
    declare -A pkg_map
    for item in "${options[@]}"; do
        local pkg label
        pkg=$(echo "$item" | awk '{print $1}')
        label=$(echo "$item" | awk '{$1=""; print $0}' | sed 's/^ *//')
        display_list+=("$pkg  — $label")
        pkg_map["$pkg  — $label"]="$pkg"
    done

    local chosen=""
    chosen=$(printf '%s\n' "${display_list[@]}" | gum choose --no-limit --height 20 --header "Extra packages (space to select):") || true

    EXTRA_PKGS=""
    while IFS= read -r line; do
        [[ -n "$line" ]] && EXTRA_PKGS="$EXTRA_PKGS ${pkg_map[$line]:-}"
    done <<< "$chosen"
    EXTRA_PKGS=$(echo "$EXTRA_PKGS" | xargs)

    if [[ -n "$EXTRA_PKGS" ]]; then
        show_success "Selected: $EXTRA_PKGS"
    else
        show_info "No extra packages selected"
    fi
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# VALIDATION & SUMMARY
# ────────────────────────────────────────────────────────────────────────────────

validate_config() {
    local errors=()
    if [[ "${CONFIG[partition_mode]}" == "manual" ]]; then
        [[ -z "${CONFIG[root_part]}" ]] && errors+=("Root partition not configured")
        [[ -n "${CONFIG[root_part]}" && ! -b "${CONFIG[root_part]}" ]] && errors+=("Root partition '${CONFIG[root_part]}' not a valid block device")
        [[ -n "${CONFIG[boot_part]}" && ! -b "${CONFIG[boot_part]}" ]] && errors+=("Boot partition '${CONFIG[boot_part]}' not a valid block device")
    else
        [[ -z "${CONFIG[disk]}" ]] && errors+=("Disk not configured")
    fi
    [[ -z "${CONFIG[username]}" ]]      && errors+=("User account not configured")
    [[ -z "${CONFIG[user_password]}" ]] && errors+=("User password not set")
    [[ -z "${CONFIG[root_password]}" ]] && errors+=("Root password not set")

    if [[ ${#errors[@]} -gt 0 ]]; then
        show_header
        gum style --foreground 196 --bold --margin "1 2" "❌ Configuration Incomplete"
        echo ""
        for e in "${errors[@]}"; do show_error "$e"; done
        echo ""
        gum input --placeholder "Press Enter to continue..."
        return 1
    fi
    return 0
}

show_summary() {
    show_header
    show_submenu_header "📋 Installation Summary"
    echo ""

    local encrypt_status="No"
    [[ "${CONFIG[encrypt]}" == "yes" && "${CONFIG[encrypt_boot]}" == "yes" ]] && encrypt_status="Yes (root+boot)"
    [[ "${CONFIG[encrypt]}" == "yes" && "${CONFIG[encrypt_boot]}" != "yes" ]] && encrypt_status="Yes (root only)"

    local boot_mode="BIOS/Legacy"
    [[ "${CONFIG[uefi]}" == "yes" ]] && boot_mode="UEFI"

    local disk_line="${CONFIG[disk]:-N/A}"
    [[ "${CONFIG[partition_mode]}" == "manual" ]] && disk_line="root=${CONFIG[root_part]} boot=${CONFIG[boot_part]:-none}"

    local cachyos_opt_line="No (vanilla Arch packages)"
    [[ "${CONFIG[cachyos_optimized]}" == "yes" ]] && cachyos_opt_line="Yes (x86-64-v3/v4)"

    gum style --border rounded --border-foreground 212 --padding "1 2" --margin "0 2" \
        "Locale:       ${CONFIG[locale]}" \
        "Keyboard:     ${CONFIG[keyboard]}" \
        "Timezone:     ${CONFIG[timezone]}" \
        "Hostname:     ${CONFIG[hostname]}" \
        "Username:     ${CONFIG[username]}" \
        "" \
        "Disk:         $disk_line" \
        "Partition:    ${CONFIG[partition_mode]}" \
        "Filesystem:   ${CONFIG[filesystem]}" \
        "Encryption:   $encrypt_status" \
        "Swap:         ${CONFIG[swap]}" \
        "" \
        "Graphics:     Auto-detect (chwd)" \
        "Optimized:    $cachyos_opt_line" \
        "Boot Mode:    $boot_mode" \
        "AUR Helper:   ${CONFIG[aur_helper]}" \
        "Login Mgr:    ${CONFIG[login_manager]}" \
        "Downloads:    ${CONFIG[parallel_downloads]} parallel" \
        "Extra pkgs:   ${EXTRA_PKGS:-none}"
    echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# MAIN MENU
# ────────────────────────────────────────────────────────────────────────────────

show_main_menu() {
    while true; do
        show_header
        local boot_mode="BIOS"
        [[ "${CONFIG[uefi]}" == "yes" ]] && boot_mode="UEFI"
        gum style --foreground 245 --margin "0 2" "Boot Mode: $boot_mode"
        echo ""

        local disk_info="${CONFIG[disk]:-Not configured}"
        [[ "${CONFIG[partition_mode]}" == "manual" && -n "${CONFIG[root_part]}" ]] && \
            disk_info="Manual: root=${CONFIG[root_part]}"

        local cachyos_opt_status="no"
        [[ "${CONFIG[cachyos_optimized]}" == "yes" ]] && cachyos_opt_status="yes (x86-64-v3/v4)"

        local menu_items=(
            ""
            "1.  🗺️  Locales            │ ${CONFIG[locale]} / ${CONFIG[keyboard]}"
            "2.  💾 Disk               │ $disk_info (${CONFIG[filesystem]})"
            "3.  🔄 Swap               │ ${CONFIG[swap]}"
            "4.  💻 Hostname           │ ${CONFIG[hostname]}"
            "5.  👤 Authentication     │ ${CONFIG[username]:-Not configured}"
            "6.  🕐 Timezone           │ ${CONFIG[timezone]}"
            "7.  ⚡ Parallel DLs       │ ${CONFIG[parallel_downloads]}"
            "8.  🔧 AUR Helper         │ ${CONFIG[aur_helper]}"
            "9.  🔐 Login Manager      │ ${CONFIG[login_manager]}"
            "10. 🚀 CachyOS Optimized  │ $cachyos_opt_status"
            "11. 📦 Extra Packages     │ ${EXTRA_PKGS:-none}"
            "──────────────────────────────────────────────"
            "12. ✅ Start Installation"
            "0.  ❌ Exit"
        )

        local sel=""
        sel=$(printf '%s\n' "${menu_items[@]}" | gum choose --height 18 \
            --header $'Configure your installation:\n') || true

        case "$sel" in
            "1."*)  select_locales ;;
            "2."*)  select_partitioning_mode ;;
            "3."*)  configure_swap ;;
            "4."*)  configure_hostname ;;
            "5."*)  configure_authentication ;;
            "6."*)  select_timezone ;;
            "7."*)  configure_parallel_downloads ;;
            "8."*)  select_aur_helper ;;
            "9."*)  select_login_manager ;;
            "10."*) toggle_cachyos_optimized ;;
            "11."*) select_extra_packages ;;
            "12."*)
                if validate_config; then
                    show_summary
                    local confirm_msg="THIS WILL ERASE ${CONFIG[disk]}. Continue?"
                    [[ "${CONFIG[partition_mode]}" == "manual" ]] && \
                        confirm_msg="${CONFIG[root_part]} will be formatted as root. Continue?"
                    if confirm_action "$confirm_msg"; then
                        perform_installation
                        break
                    fi
                fi
                ;;
            "0."*)
                confirm_action "Exit installer?" && { echo "Cancelled."; exit 0; }
                ;;
        esac
    done
}

# ────────────────────────────────────────────────────────────────────────────────
# PACMAN HELPERS
# ────────────────────────────────────────────────────────────────────────────────

apply_parallel_downloads() {
    local conf="$1" count="${CONFIG[parallel_downloads]}"
    grep -q '^#*ParallelDownloads' "$conf" \
        && sed -i "s/^#*ParallelDownloads.*/ParallelDownloads = $count/" "$conf" \
        || sed -i '/^\[options\]/a ParallelDownloads = '"$count" "$conf"
}

configure_pacman_options() {
    local conf="$1"
    for opt in Color ILoveCandy VerbosePkgLists DisableDownloadTimeout; do
        grep -q "^#\s*${opt}" "$conf" \
            && sed -i "s/^#\s*${opt}.*/${opt}/" "$conf" \
            || grep -q "^${opt}" "$conf" \
            || sed -i '/^\[options\]/a '"${opt}" "$conf"
    done
}

# ────────────────────────────────────────────────────────────────────────────────
# DISK OPERATIONS
# ────────────────────────────────────────────────────────────────────────────────

partition_disk() {
    [[ "${CONFIG[partition_mode]}" == "manual" ]] && return 0

    local disk="${CONFIG[disk]}"
    [[ -n "$disk" ]] || { echo "ERROR: CONFIG[disk] is empty"; exit 1; }

    wipefs -af "$disk" 2>/dev/null || true
    sgdisk -Z "$disk" &>/dev/null || true

    if [[ "${CONFIG[uefi]}" == "yes" ]]; then
        parted -s "$disk" mklabel gpt
        parted -s "$disk" mkpart ESP fat32 1MiB 2049MiB
        parted -s "$disk" set 1 esp on
        parted -s "$disk" mkpart primary 2049MiB 100%
    elif [[ "${CONFIG[encrypt]}" == "yes" && "${CONFIG[encrypt_boot]}" == "yes" ]]; then
        parted -s "$disk" mklabel msdos
        parted -s "$disk" mkpart primary 1MiB 100%
    else
        parted -s "$disk" mklabel msdos
        parted -s "$disk" mkpart primary ext4 1MiB 2049MiB
        parted -s "$disk" set 1 boot on
        parted -s "$disk" mkpart primary 2049MiB 100%
    fi

    partprobe "$disk" || true; udevadm settle; sleep 1

    if [[ "${CONFIG[encrypt]}" == "yes" && "${CONFIG[encrypt_boot]}" == "yes" && "${CONFIG[uefi]}" != "yes" ]]; then
        CONFIG[boot_part]=""
        [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]] && CONFIG[root_part]="${disk}p1" || CONFIG[root_part]="${disk}1"
    else
        [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]] \
            && { CONFIG[boot_part]="${disk}p1"; CONFIG[root_part]="${disk}p2"; } \
            || { CONFIG[boot_part]="${disk}1";  CONFIG[root_part]="${disk}2"; }
    fi

    [[ -n "${CONFIG[boot_part]}" && ! -b "${CONFIG[boot_part]}" ]] && { echo "ERROR: boot_part not ready"; exit 1; }
    [[ -b "${CONFIG[root_part]}" ]] || { echo "ERROR: root_part not ready"; lsblk -f "$disk"; exit 1; }
}

setup_encryption() {
    [[ "${CONFIG[encrypt]}" == "yes" ]] || return 0
    [[ -n "${CONFIG[encrypt_password]}" ]] || { echo "ERROR: encrypt_password empty"; exit 1; }
    [[ -b "${CONFIG[root_part]}" ]] || { echo "ERROR: root_part not a block device"; exit 1; }

    echo -n "${CONFIG[encrypt_password]}" | cryptsetup luksFormat --type luks2 "${CONFIG[root_part]}" -
    echo -n "${CONFIG[encrypt_password]}" | cryptsetup open "${CONFIG[root_part]}" cryptroot -
    CONFIG[root_device]="/dev/mapper/cryptroot"
    [[ -b "${CONFIG[root_device]}" ]] || { echo "ERROR: cryptroot mapper not created"; exit 1; }
}

format_partitions() {
    local root_dev="${CONFIG[root_part]}"
    [[ "${CONFIG[encrypt]}" == "yes" ]] && root_dev="${CONFIG[root_device]}"
    [[ -b "$root_dev" ]] || { echo "ERROR: root device '$root_dev' not a block device"; exit 1; }

    if [[ -n "${CONFIG[boot_part]}" ]]; then
        [[ -b "${CONFIG[boot_part]}" ]] || { echo "ERROR: boot_part not a block device"; exit 1; }
        if [[ "${CONFIG[reuse_efi]}" == "yes" ]]; then
            echo "Reusing existing EFI — skipping format"
        elif [[ "${CONFIG[uefi]}" == "yes" ]]; then
            wipefs -af "${CONFIG[boot_part]}" &>/dev/null
            mkfs.fat -F32 "${CONFIG[boot_part]}"
        else
            wipefs -af "${CONFIG[boot_part]}" &>/dev/null
            mkfs.ext4 -F "${CONFIG[boot_part]}"
        fi
    fi

    wipefs -af "$root_dev" &>/dev/null
    case "${CONFIG[filesystem]}" in
        btrfs) mkfs.btrfs -f "$root_dev" ;;
        ext4)  mkfs.ext4  -F "$root_dev" ;;
        xfs)   mkfs.xfs   -f "$root_dev" ;;
        *)     echo "ERROR: Unknown filesystem '${CONFIG[filesystem]}'"; exit 1 ;;
    esac
}

mount_filesystems() {
    local root_dev="${CONFIG[root_part]}"
    [[ "${CONFIG[encrypt]}" == "yes" ]] && root_dev="${CONFIG[root_device]}"
    [[ -b "$root_dev" ]] || { echo "ERROR: root device not a block device"; exit 1; }

    if [[ "${CONFIG[filesystem]}" == "btrfs" ]]; then
        mount "$root_dev" "$MOUNTPOINT"
        btrfs subvolume create "$MOUNTPOINT/@"
        btrfs subvolume create "$MOUNTPOINT/@home"
        btrfs subvolume create "$MOUNTPOINT/@var"
        btrfs subvolume create "$MOUNTPOINT/@tmp"
        btrfs subvolume create "$MOUNTPOINT/@snapshots"
        umount "$MOUNTPOINT"
        mount -o noatime,compress=zstd,subvol=@ "$root_dev" "$MOUNTPOINT"
        mkdir -p "$MOUNTPOINT"/{home,var,tmp,.snapshots,boot}
        mount -o noatime,compress=zstd,subvol=@home "$root_dev" "$MOUNTPOINT/home"
        mount -o noatime,compress=zstd,subvol=@var  "$root_dev" "$MOUNTPOINT/var"
        mount -o noatime,compress=zstd,subvol=@tmp  "$root_dev" "$MOUNTPOINT/tmp"
        mount -o noatime,compress=zstd,subvol=@snapshots "$root_dev" "$MOUNTPOINT/.snapshots"
    else
        mount "$root_dev" "$MOUNTPOINT"
        mkdir -p "$MOUNTPOINT/boot"
    fi

    if [[ "${CONFIG[uefi]}" == "yes" && -n "${CONFIG[boot_part]}" ]]; then
        if [[ "${CONFIG[encrypt]}" == "yes" && "${CONFIG[encrypt_boot]}" == "no" ]]; then
            mkdir -p "$MOUNTPOINT/boot"
            mount "${CONFIG[boot_part]}" "$MOUNTPOINT/boot"
        else
            mkdir -p "$MOUNTPOINT/boot/efi"
            mount "${CONFIG[boot_part]}" "$MOUNTPOINT/boot/efi"
        fi
    elif [[ -n "${CONFIG[boot_part]}" ]]; then
        mount "${CONFIG[boot_part]}" "$MOUNTPOINT/boot"
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# BASE SYSTEM
# ────────────────────────────────────────────────────────────────────────────────

add_temp_repo() {
    sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/[multilib]\nInclude/}' /etc/pacman.conf

    if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf; then
        pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        pacman-key --lsign-key 3056513887B78AEB
        pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
        pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> /etc/pacman.conf
    fi

    apply_parallel_downloads /etc/pacman.conf
    configure_pacman_options /etc/pacman.conf
    pacman -Sy
}

install_base_system() {
    add_temp_repo

    local packages="base base-devel linux-zen linux-zen-headers"

    grep -q "GenuineIntel" /proc/cpuinfo && packages+=" intel-ucode"
    grep -q "AuthenticAMD" /proc/cpuinfo && packages+=" amd-ucode"

    # Boot & filesystem
    packages+=" grub efibootmgr os-prober"
    packages+=" btrfs-progs dosfstools e2fsprogs xfsprogs gptfdisk"

    # Base utilities
    packages+=" sudo nano vim git wget curl"

    # Network
    packages+=" networkmanager iw iwd ppp openssh wpa_supplicant wireless_tools"
    packages+=" avahi nss-mdns dhcpcd"

    # Bluetooth
    packages+=" bluez bluez-libs bluez-utils"

    # Audio (PipeWire)
    packages+=" pipewire wireplumber pipewire-jack pipewire-alsa pipewire-pulse"
    packages+=" alsa-utils alsa-plugins alsa-firmware"

    # GStreamer (minimal)
    packages+=" gstreamer gst-libav gst-plugins-good gst-plugins-bad gst-plugin-pipewire"

    # Printing
    packages+=" cups"

    # Xorg/Wayland base
    packages+=" xorg-server xorg-xwayland xorg-xinit"

    # Firmware
    packages+=" fwupd sof-firmware linux-firmware"

    pacstrap -K "$MOUNTPOINT" $packages
    genfstab -U "$MOUNTPOINT" >> "$MOUNTPOINT/etc/fstab"
}

add_repos() {
    sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/[multilib]\nInclude/}' "$MOUNTPOINT/etc/pacman.conf"

    if ! grep -q "\[chaotic-aur\]" "$MOUNTPOINT/etc/pacman.conf"; then
        arch-chroot "$MOUNTPOINT" pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
        arch-chroot "$MOUNTPOINT" pacman-key --lsign-key 3056513887B78AEB
        arch-chroot "$MOUNTPOINT" pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
        arch-chroot "$MOUNTPOINT" pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' >> "$MOUNTPOINT/etc/pacman.conf"
    fi

    # ── CachyOS repo (provides chwd for hardware auto-detection) ──────────
    if ! grep -q "\[cachyos\]" "$MOUNTPOINT/etc/pacman.conf"; then
        show_info "  Adding CachyOS repository..."
        arch-chroot "$MOUNTPOINT" bash -c '
            cd /tmp
            curl -sSL https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
            tar xf cachyos-repo.tar.xz
            cd cachyos-repo
            yes | ./cachyos-repo.sh
            rm -rf /tmp/cachyos-repo /tmp/cachyos-repo.tar.xz
        '
    fi

    apply_parallel_downloads "$MOUNTPOINT/etc/pacman.conf"
    configure_pacman_options "$MOUNTPOINT/etc/pacman.conf"
    arch-chroot "$MOUNTPOINT" pacman -Sy
}

configure_system() {
    arch-chroot "$MOUNTPOINT" ln -sf "/usr/share/zoneinfo/${CONFIG[timezone]}" /etc/localtime
    arch-chroot "$MOUNTPOINT" hwclock --systohc

    echo "${CONFIG[locale]} UTF-8" >> "$MOUNTPOINT/etc/locale.gen"
    echo "en_US.UTF-8 UTF-8"       >> "$MOUNTPOINT/etc/locale.gen"
    arch-chroot "$MOUNTPOINT" locale-gen
    echo "LANG=${CONFIG[locale]}" > "$MOUNTPOINT/etc/locale.conf"
    echo "KEYMAP=${CONFIG[keyboard]}" > "$MOUNTPOINT/etc/vconsole.conf"

    echo "${CONFIG[hostname]}" > "$MOUNTPOINT/etc/hostname"
    cat > "$MOUNTPOINT/etc/hosts" << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${CONFIG[hostname]}.localdomain ${CONFIG[hostname]}
EOF

    arch-chroot "$MOUNTPOINT" systemctl enable NetworkManager avahi-daemon

    mkdir -p "$MOUNTPOINT/etc/NetworkManager/conf.d"
    cat > "$MOUNTPOINT/etc/NetworkManager/conf.d/wifi-backend.conf" << EOF
[device]
wifi.backend=wpa_supplicant
EOF

    if [[ "${CONFIG[encrypt]}" == "yes" ]]; then
        sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' \
            "$MOUNTPOINT/etc/mkinitcpio.conf"
        arch-chroot "$MOUNTPOINT" mkinitcpio -P
    fi
}

install_bootloader() {
    local efi_dir="/boot/efi"

    if [[ "${CONFIG[uefi]}" == "yes" ]]; then
        [[ "${CONFIG[encrypt]}" == "yes" && "${CONFIG[encrypt_boot]}" == "no" ]] && efi_dir="/boot" || efi_dir="/boot/efi"
        mkdir -p "$MOUNTPOINT$efi_dir"
        mountpoint -q "$MOUNTPOINT$efi_dir" || mount "${CONFIG[boot_part]}" "$MOUNTPOINT$efi_dir"

        if [[ "${CONFIG[encrypt_boot]}" == "yes" && "${CONFIG[encrypt]}" == "yes" ]]; then
            grep -q '^GRUB_ENABLE_CRYPTODISK=' "$MOUNTPOINT/etc/default/grub" \
                && sed -i 's/^GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' "$MOUNTPOINT/etc/default/grub" \
                || echo 'GRUB_ENABLE_CRYPTODISK=y' >> "$MOUNTPOINT/etc/default/grub"
            arch-chroot "$MOUNTPOINT" grub-install \
                --target=x86_64-efi --efi-directory="$efi_dir" \
                --bootloader-id=OrbitOS --removable --recheck \
                --modules="part_gpt part_msdos luks2 cryptodisk gcry_rijndael gcry_sha256"
        else
            arch-chroot "$MOUNTPOINT" grub-install \
                --target=x86_64-efi --efi-directory="$efi_dir" \
                --bootloader-id=OrbitOS --removable --recheck
        fi
    else
        if [[ "${CONFIG[encrypt_boot]}" == "yes" && "${CONFIG[encrypt]}" == "yes" ]]; then
            grep -q '^GRUB_ENABLE_CRYPTODISK=' "$MOUNTPOINT/etc/default/grub" \
                && sed -i 's/^GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' "$MOUNTPOINT/etc/default/grub" \
                || echo 'GRUB_ENABLE_CRYPTODISK=y' >> "$MOUNTPOINT/etc/default/grub"
            arch-chroot "$MOUNTPOINT" grub-install \
                --target=i386-pc --recheck \
                --modules="part_msdos luks2 cryptodisk gcry_rijndael gcry_sha256" \
                "${CONFIG[disk]}"
        else
            arch-chroot "$MOUNTPOINT" grub-install --target=i386-pc "${CONFIG[disk]}"
        fi
    fi

    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 nvme_load=yes"/' \
        "$MOUNTPOINT/etc/default/grub"
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="OrbitOS"/' "$MOUNTPOINT/etc/default/grub"
    sed -i 's/^#*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$MOUNTPOINT/etc/default/grub"

    if [[ "${CONFIG[encrypt]}" == "yes" ]]; then
        local uuid=""
        uuid=$(blkid -s UUID -o value "${CONFIG[root_part]}")
        sed -i "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"rd.luks.name=${uuid}=cryptroot root=/dev/mapper/cryptroot\"|" \
            "$MOUNTPOINT/etc/default/grub"
    fi

    arch-chroot "$MOUNTPOINT" grub-mkconfig -o /boot/grub/grub.cfg
}

create_user() {
    echo "root:${CONFIG[root_password]}" | arch-chroot "$MOUNTPOINT" chpasswd

    local groups_to_create="sys network scanner power cups realtime rfkill lp users video storage kvm optical audio wheel adm"
    for grp in $groups_to_create; do
        arch-chroot "$MOUNTPOINT" groupadd -f "$grp" 2>/dev/null || true
    done

    arch-chroot "$MOUNTPOINT" useradd -m \
        -G sys,network,scanner,power,cups,realtime,rfkill,lp,users,video,storage,kvm,optical,audio,wheel,adm \
        -s /bin/bash "${CONFIG[username]}"
    echo "${CONFIG[username]}:${CONFIG[user_password]}" | arch-chroot "$MOUNTPOINT" chpasswd
    sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' "$MOUNTPOINT/etc/sudoers"
}

install_drivers_chwd() {
    # ── Verify kernel state ───────────────────────────────────────────────
    # Ensure only linux-zen is installed — no CachyOS kernels that would
    # confuse chwd's conditional_packages logic.
    show_info "  Verifying kernel state (linux-zen only)..."

    local stray_kernels=""
    stray_kernels=$(arch-chroot "$MOUNTPOINT" pacman -Qqs '^linux-cachyos' 2>/dev/null || true)
    if [[ -n "$stray_kernels" ]]; then
        show_warning "Unexpected CachyOS kernels detected — removing to avoid conflicts:"
        show_warning "  $stray_kernels"
        arch-chroot "$MOUNTPOINT" pacman -Rdd --noconfirm $stray_kernels 2>/dev/null || true
    fi

    # Confirm linux-zen + headers are present (pacstrap should have them)
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed linux-zen linux-zen-headers

    show_success "Kernel verified: linux-zen + linux-zen-headers"

    # ── Install chwd ──────────────────────────────────────────────────────
    show_info "  Installing chwd hardware detection..."
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed chwd \
        || { show_warning "chwd install failed — skipping auto-detection. Install drivers manually after reboot."; return 0; }

    show_success "chwd installed"

    # ── Run auto-detection ────────────────────────────────────────────────
    # chwd -a pci scans all PCI devices and installs the highest-priority
    # matching profile for each GPU class (0300/0302/0380).
    # It handles: package installation, mkinitcpio module injection (via
    # /etc/mkinitcpio.conf.d/10-chwd.conf), laptop detection (nvidia-prime,
    # switcheroo, powerd), kms hook removal on desktops, and VM guest tools.
    show_info "  Auto-detecting hardware and installing drivers..."
    arch-chroot "$MOUNTPOINT" chwd -a pci -f \
        || { show_warning "chwd auto-detection failed — install drivers manually after reboot."; return 0; }

    show_success "Hardware drivers installed via chwd"

    # ── Post-chwd: GRUB kernel parameters for NVIDIA ──────────────────────
    # chwd handles mkinitcpio but NOT grub cmdline. If nvidia modules were
    # injected, add the required kernel parameters.
    if [[ -f "$MOUNTPOINT/etc/mkinitcpio.conf.d/10-chwd.conf" ]] \
       && grep -q 'nvidia' "$MOUNTPOINT/etc/mkinitcpio.conf.d/10-chwd.conf" 2>/dev/null; then
        show_info "  NVIDIA detected — adding kernel parameters to GRUB..."
        local current_cmdline=""
        current_cmdline=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$MOUNTPOINT/etc/default/grub" \
            | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT="//;s/"$//')

        local params_to_add=""
        [[ "$current_cmdline" != *"nvidia_drm.modeset=1"* ]] && params_to_add+=" nvidia_drm.modeset=1"
        [[ "$current_cmdline" != *"nvidia_drm.fbdev=1"* ]]   && params_to_add+=" nvidia_drm.fbdev=1"

        if [[ -n "$params_to_add" ]]; then
            sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1${params_to_add}\"|" \
                "$MOUNTPOINT/etc/default/grub"
        fi

        arch-chroot "$MOUNTPOINT" grub-mkconfig -o /boot/grub/grub.cfg
        show_success "NVIDIA kernel parameters configured"
    fi

    # ── Rebuild initramfs with chwd's module config ───────────────────────
    arch-chroot "$MOUNTPOINT" mkinitcpio -P
    show_success "Initramfs rebuilt"
}

setup_swap_system() {
    case "${CONFIG[swap]}" in
        zram)
            arch-chroot "$MOUNTPOINT" pacman -S --noconfirm zram-generator
            cat > "$MOUNTPOINT/etc/systemd/zram-generator.conf" << EOF
[zram0]
zram-size = ram / 2
compression-algorithm = ${CONFIG[swap_algo]}
EOF
            ;;
        file)
            if [[ "${CONFIG[filesystem]}" == "btrfs" ]]; then
                arch-chroot "$MOUNTPOINT" truncate -s 0 /swapfile
                arch-chroot "$MOUNTPOINT" chattr +C /swapfile
                arch-chroot "$MOUNTPOINT" fallocate -l 4G /swapfile
            else
                arch-chroot "$MOUNTPOINT" dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
            fi
            arch-chroot "$MOUNTPOINT" chmod 600 /swapfile
            arch-chroot "$MOUNTPOINT" mkswap /swapfile
            echo "/swapfile none swap defaults 0 0" >> "$MOUNTPOINT/etc/fstab"
            ;;
        none) ;;
    esac
}

# ────────────────────────────────────────────────────────────────────────────────
# MINIMAL KDE INSTALL
# ────────────────────────────────────────────────────────────────────────────────
#
# Minimal philosophy:
#   - Core Plasma shell + Wayland support
#   - Essential KDE apps (Dolphin, Konsole, Kate, Spectacle, Gwenview, Ark, Okular)
#   - No game tools, no ISO tools, no clonezilla/partclone bloat
#   - AUR helper, fastfetch, btop — and that's it
#   - CyberXero Toolkit + PS4 Plasma Theme installed as OrbitOS extras
#

install_kde_minimal() {
    show_info "Installing minimal KDE Plasma..."

    arch-chroot "$MOUNTPOINT" pacman -Syu --noconfirm

    # ── Core Plasma shell ─────────────────────────────────────────────────────
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed \
        plasma-desktop plasma-workspace kwin systemsettings \
        kactivitymanagerd kdecoration layer-shell-qt \
        polkit-kde-agent ksystemstats plasma-integration \
        kscreenlocker kglobalacceld \
        kscreen libkscreen \
        plasma-nm plasma-pa bluedevil \
        powerdevil \
        breeze breeze-gtk \
        kdeplasma-addons \
        kinfocenter \
        plasma-systemmonitor \
        xdg-desktop-portal-kde \
        polkit-qt6 \
        qqc2-breeze-style

    # ── Wayland support ───────────────────────────────────────────────────────
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed \
        egl-wayland qt6-wayland lib32-wayland wayland-protocols \
        kwayland-integration plasma-wayland-protocols \
        xorg-xwayland

    # ── Essential KDE applications ────────────────────────────────────────────
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed \
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

    # ── Thumbnail / file previews ─────────────────────────────────────────────
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed \
        tumbler ffmpegthumbnailer poppler-qt6 \
        kdegraphics-thumbnailers

    # ── System utilities ──────────────────────────────────────────────────────
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed \
        gvfs gvfs-mtp gvfs-smb gvfs-afc udisks2 udiskie \
        xdg-utils xdg-user-dirs \
        flatpak \
        power-profiles-daemon \
        switcheroo-control \
        brightnessctl \
        ntfs-3g exfatprogs \
        p7zip unrar unzip zip \
        btop htop fastfetch \
        bash-completion \
        inxi pciutils usbutils \
        pacman-contrib \
        topgrade

    # ── Fonts (essential) ─────────────────────────────────────────────────────
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed \
        ttf-hack-nerd ttf-jetbrains-mono-nerd \
        ttf-ubuntu-font-family adobe-source-sans-fonts \
        noto-fonts noto-fonts-emoji

    # ── AUR helper ────────────────────────────────────────────────────────────
    show_info "Installing AUR helper (${CONFIG[aur_helper]})..."
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed "${CONFIG[aur_helper]}" \
        || show_warning "AUR helper install failed — install manually after reboot"

    # ── Login manager ─────────────────────────────────────────────────────────
    case "${CONFIG[login_manager]}" in
        plasma-login)
            arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed plasma-login-manager
            arch-chroot "$MOUNTPOINT" systemctl enable plasmalogin.service
            ;;
        *)
            arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed sddm
            arch-chroot "$MOUNTPOINT" systemctl enable sddm.service
            ;;
    esac

    # ── Extra user-selected packages ──────────────────────────────────────────
    if [[ -n "$EXTRA_PKGS" ]]; then
        show_info "Installing extra packages: $EXTRA_PKGS"
        arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed $EXTRA_PKGS \
            || show_warning "Some extra packages failed — install manually after reboot"
    fi

    # ── Services ──────────────────────────────────────────────────────────────
    arch-chroot "$MOUNTPOINT" systemctl enable \
        cups.socket \
        bluetooth \
        power-profiles-daemon \
        switcheroo-control \
        wpa_supplicant

    arch-chroot "$MOUNTPOINT" systemctl disable iwd         2>/dev/null || true
    arch-chroot "$MOUNTPOINT" systemctl disable dhcpcd      2>/dev/null || true

    # ── XDG user dirs ─────────────────────────────────────────────────────────
    arch-chroot "$MOUNTPOINT" su -l "${CONFIG[username]}" -c "xdg-user-dirs-update" 2>/dev/null || true

    # ── Fastfetch on terminal start ───────────────────────────────────────────
    local user_bashrc="$MOUNTPOINT/home/${CONFIG[username]}/.bashrc"
    if ! grep -qF "fastfetch" "$user_bashrc" 2>/dev/null; then
        echo "" >> "$user_bashrc"
        echo "# OrbitOS: show system info on terminal start" >> "$user_bashrc"
        echo "fastfetch" >> "$user_bashrc"
    fi
    arch-chroot "$MOUNTPOINT" chown "${CONFIG[username]}:${CONFIG[username]}" \
        "/home/${CONFIG[username]}/.bashrc" 2>/dev/null || true

    show_success "Minimal KDE Plasma installed"
}

# ────────────────────────────────────────────────────────────────────────────────
# ORBITOS EXTRAS: CyberXero Toolkit + PS4 Plasma Theme
# ────────────────────────────────────────────────────────────────────────────────
#
# CyberXero Toolkit: built from source (Rust/GTK4) during installation.
# PS4 Plasma Theme:  assets + first-boot autostart script, because applying
#                    the theme requires a live Plasma session (qdbus6, plasmashell
#                    restart, video wallpaper activation, compiled KWin effects).
#                    A one-shot .desktop entry runs install.sh on first login,
#                    then removes itself so it never runs again.
#

install_orbit_extras() {
    show_info "Installing OrbitOS extras: CyberXero Toolkit + PS4 Plasma Theme..."

    # ── Extra build/runtime dependencies ─────────────────────────────────────
    show_info "  Installing toolkit build dependencies..."
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed \
        rust cargo pkgconf \
        gtk4 glib2 libadwaita vte4 \
        polkit \
        cmake extra-cmake-modules \
        kitty cava imagemagick \
        scx-scheds \
        || show_warning "Some extra dependencies failed to install — toolkit build may fail"

    # ── Clone and build CyberXero Toolkit as the new user ────────────────────
    show_info "  Cloning & building CyberXero Toolkit (Rust — may take a few minutes)..."
    arch-chroot "$MOUNTPOINT" su -l "${CONFIG[username]}" -c "
        set -e
        cd \$HOME
        git clone https://github.com/synsejse/xero-toolkit CyberXero-Toolkit 2>&1 | tail -3
        cd CyberXero-Toolkit
        cargo build --release 2>&1 | grep -E '^(error|Compiling|Finished)' | tail -20
    " || { show_warning "Toolkit build failed — skipping toolkit install. Re-run ~/CyberXero-Toolkit/install.sh after reboot."; return 0; }

    # ── Install toolkit binaries and assets (root step) ──────────────────────
    show_info "  Installing toolkit binaries..."
    arch-chroot "$MOUNTPOINT" bash << TOOLINSTALL
set -e
SRC="/home/${CONFIG[username]}/CyberXero-Toolkit"

mkdir -p /opt/xero-toolkit/sources/scripts /opt/xero-toolkit/sources/systemd

install -Dm755 "\$SRC/target/release/xero-toolkit" /opt/xero-toolkit/xero-toolkit
install -Dm755 "\$SRC/target/release/xero-authd"   /opt/xero-toolkit/xero-authd   2>/dev/null || true
install -Dm755 "\$SRC/target/release/xero-auth"    /opt/xero-toolkit/xero-auth    2>/dev/null || true

[[ -d "\$SRC/sources/scripts" ]] && install -m755 "\$SRC/sources/scripts/"* /opt/xero-toolkit/sources/scripts/ 2>/dev/null || true
[[ -d "\$SRC/sources/systemd" ]] && install -m644 "\$SRC/sources/systemd/"* /opt/xero-toolkit/sources/systemd/ 2>/dev/null || true

ln -sf /opt/xero-toolkit/xero-toolkit /usr/bin/xero-toolkit

install -Dm644 "\$SRC/packaging/xero-toolkit.desktop" \
    /usr/share/applications/xero-toolkit.desktop
install -Dm644 "\$SRC/gui/resources/icons/scalable/apps/xero-toolkit.png" \
    /usr/share/icons/hicolor/scalable/apps/xero-toolkit.png
gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true

if [[ -d "\$SRC/extra-scripts/usr/local/bin" ]]; then
    for script in "\$SRC/extra-scripts/usr/local/bin/"*; do
        [[ -f "\$script" ]] && install -Dm755 "\$script" "/usr/local/bin/\$(basename "\$script")"
    done
fi

# Clean up cargo build artifacts (~1-2 GB)
rm -rf "\$SRC/target"
TOOLINSTALL

    show_success "CyberXero Toolkit installed → /opt/xero-toolkit  (run: xero-toolkit)"

    # ── PS4 Plasma Theme: deploy first-boot autostart ─────────────────────────
    # The theme installer requires a live Plasma session: qdbus6 panel scripting,
    # plasmashell restart, KWin effects compilation, video wallpaper activation.
    # We drop a one-shot autostart that runs install.sh on first login and
    # removes itself so it never fires again.
    show_info "  Preparing PS4 Plasma Theme first-boot autostart..."

    local autostart_dir="$MOUNTPOINT/home/${CONFIG[username]}/.config/autostart"
    mkdir -p "$autostart_dir"

    # ── First-boot runner script ──────────────────────────────────────────────
    cat > "$autostart_dir/orbitos-ps4-theme.sh" << 'FIRSTBOOT'
#!/usr/bin/env bash
# OrbitOS — PS4 Plasma Theme first-boot installer.
# Runs once on first login, then removes itself.

SELF_SCRIPT="$HOME/.config/autostart/orbitos-ps4-theme.sh"
SELF_DESKTOP="$HOME/.config/autostart/orbitos-ps4-theme.desktop"
REPO_DIR="$HOME/Playstation-4-Plasma"

log()  { printf "\033[1;36m[OrbitOS]\033[0m %s\n" "$1"; }
ok()   { printf "\033[1;32m[  OK   ]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[  !!   ]\033[0m %s\n" "$1"; }
err()  { printf "\033[1;31m[ FAIL  ]\033[0m %s\n" "$1"; }

# Re-launch inside a terminal emulator if not already running in one
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
printf   "\033[1;35m║   OrbitOS — PS4 Plasma Theme · First-Boot Setup      ║\033[0m\n"
printf   "\033[1;35m╚══════════════════════════════════════════════════════╝\033[0m\n\n"

# ── Clone or update the theme repo ───────────────────────────────────────────
if [[ -d "$REPO_DIR/.git" ]]; then
    log "Updating existing repository..."
    git -C "$REPO_DIR" pull --rebase &>/dev/null && ok "Repository updated" \
        || warn "Could not update repo — proceeding with existing copy"
else
    log "Cloning Playstation-4-Plasma repository..."
    if git clone https://github.com/MurderFromMars/Playstation-4-Plasma "$REPO_DIR"; then
        ok "Repository cloned"
    else
        err "Failed to clone repository — check your internet connection."
        echo ""
        echo "  To retry later, run:  bash ~/.config/autostart/orbitos-ps4-theme.sh"
        sleep 15
        exit 1
    fi
fi

# ── Run upstream installer ────────────────────────────────────────────────────
log "Running PS4 Plasma theme installer..."
if bash "$REPO_DIR/install.sh"; then
    ok "PS4 Plasma Theme applied successfully!"
else
    warn "Installer finished with errors — some elements may not have applied."
    warn "Re-run manually:  bash ~/Playstation-4-Plasma/install.sh"
fi

# ── Self-destruct (run once only) ─────────────────────────────────────────────
rm -f "$SELF_DESKTOP" "$SELF_SCRIPT"
ok "First-boot setup complete. This window will close in 10 seconds."
sleep 10
FIRSTBOOT

    chmod +x "$autostart_dir/orbitos-ps4-theme.sh"

    # ── KDE autostart .desktop entry ─────────────────────────────────────────
    cat > "$autostart_dir/orbitos-ps4-theme.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=OrbitOS PS4 Theme Setup
Comment=Applies the PS4 Plasma theme on first login (runs once, then removes itself)
Exec=bash /home/${CONFIG[username]}/.config/autostart/orbitos-ps4-theme.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
X-KDE-StartupNotify=false
DESKTOP

    # Fix ownership for everything under the user's home we touched
    arch-chroot "$MOUNTPOINT" chown -R "${CONFIG[username]}:${CONFIG[username]}" \
        "/home/${CONFIG[username]}/.config/autostart" 2>/dev/null || true

    show_success "PS4 Theme first-boot autostart ready → will apply on first login"
}

# ────────────────────────────────────────────────────────────────────────────────
# MAIN INSTALLATION FLOW
# ────────────────────────────────────────────────────────────────────────────────

perform_installation() {
    show_header
    gum style --foreground 212 --bold --margin "1 2" "🚀 Starting OrbitOS Installation..."
    echo ""

    run_step "Partitioning disk..."      partition_disk
    [[ "${CONFIG[encrypt]}" == "yes" ]] && run_step "Setting up encryption..." setup_encryption
    run_step "Formatting partitions..."  format_partitions
    run_step "Mounting filesystems..."   mount_filesystems

    show_info "Installing base system (this may take a while)..."
    install_base_system
    show_success "Base system installed"

    show_info "Adding Chaotic-AUR and CachyOS repositories..."
    add_repos
    show_success "Repositories configured"

    if [[ "${CONFIG[cachyos_optimized]}" == "yes" ]]; then
        show_info "Upgrading to CachyOS optimized packages (this may take a while)..."
        arch-chroot "$MOUNTPOINT" pacman -Syu --noconfirm \
            || show_warning "Package optimization had errors — system should still be functional"
        show_success "Packages upgraded to CachyOS optimized builds"
    fi

    run_step "Configuring system..."     configure_system
    run_step "Installing bootloader..."  install_bootloader
    run_step "Creating user account..."  create_user

    show_info "Auto-detecting and installing hardware drivers (chwd)..."
    install_drivers_chwd
    show_success "Hardware drivers configured"

    show_info "Installing CachyOS gaming packages..."
    arch-chroot "$MOUNTPOINT" pacman -S --noconfirm --needed \
        cachyos-gaming-meta cachyos-gaming-applications \
        || show_warning "Some gaming packages failed — install manually after reboot: pacman -S cachyos-gaming-meta cachyos-gaming-applications"
    show_success "Gaming packages installed"

    run_step "Configuring swap..."       setup_swap_system

    show_info "Installing minimal KDE Plasma..."
    install_kde_minimal
    show_success "KDE Plasma installed"

    show_info "Installing OrbitOS extras (CyberXero Toolkit + PS4 Theme)..."
    install_orbit_extras
    show_success "OrbitOS extras installed"

    show_header
    gum style --foreground 82 --bold --border double --border-foreground 82 \
        --align center --width 64 --margin "1 2" --padding "1 2" \
        "✨ OrbitOS Installation Complete! ✨" \
        "" \
        "Remove installation media and reboot:" \
        "  sudo reboot" \
        "" \
        "On first login:" \
        "  • Gaming (Steam, Lutris, Heroic) → ready to go" \
        "  • CyberXero Toolkit → run: xero-toolkit" \
        "  • PS4 Plasma Theme  → applies automatically"
    echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ────────────────────────────────────────────────────────────────────────────────

main() {
    check_root
    check_arch_iso
    check_uefi
    check_internet
    ensure_dependencies
    show_main_menu
}

main "$@"
