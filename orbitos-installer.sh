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
# GLOBALS
# ────────────────────────────────────────────────────────────────────────────────

readonly ORBIT_VERSION="1.0"
readonly ORBIT_NAME="OrbitOS KDE Installer"
readonly ORBIT_MOUNT="/mnt"

# Optional: set this to a direct URL to your logo PNG (e.g. raw GitHub link).
# If left empty the installer will generate a simple SVG placeholder instead.
ORBIT_LOGO_URL="https://raw.githubusercontent.com/MurderFromMars/OrbitOS/main/ps4.png"

# Terminal colours — only used as fallback when gum is absent
_c_red=$'\033[0;31m'
_c_grn=$'\033[0;32m'
_c_yel=$'\033[1;33m'
_c_cyn=$'\033[0;36m'
_c_mag=$'\033[0;35m'
_c_rst=$'\033[0m'

# Installation state — all values live here
declare -A CFG
CFG[locale]="en_US.UTF-8"
CFG[keyboard]="us"
CFG[timezone]="UTC"
CFG[hostname]="orbitos"
CFG[username]=""
CFG[user_password]=""
CFG[root_password]=""
CFG[disk]=""
CFG[filesystem]="btrfs"
CFG[encrypt]="no"
CFG[encrypt_boot]="no"
CFG[encrypt_password]=""
CFG[swap]="zram"
CFG[swap_algo]="zstd"
CFG[parallel_downloads]="5"
CFG[uefi]="no"
CFG[boot_part]=""
CFG[root_part]=""
CFG[root_device]=""
CFG[partition_mode]="auto"
CFG[reuse_efi]="no"
CFG[aur_helper]="paru"
CFG[login_manager]="sddm"
CFG[cachyos_optimized]="no"
CFG[handheld]="no"

# Packages added by the user during the optional-packages step
ADDON_PKGS=""

# ────────────────────────────────────────────────────────────────────────────────
# DISPLAY LAYER
# ────────────────────────────────────────────────────────────────────────────────
# All output goes through these wrappers so the UI stays consistent whether
# gum is available or we fall back to plain echo.

_gum_present() { command -v gum &>/dev/null; }

# Print the top-level branded header
ui_header() {
    clear
    if _gum_present; then
        gum style \
            --foreground 212 --border-foreground 212 --border double \
            --align center --width 70 --margin "1 2" --padding "1 2" \
            "✨ $ORBIT_NAME v$ORBIT_VERSION ✨" \
            "" \
            "Arch Linux + KDE Plasma + Gaming + PS4 Theme + CyberXero Toolkit"
    else
        printf "\n${_c_mag}  ✨ %s v%s ✨${_c_rst}\n\n" "$ORBIT_NAME" "$ORBIT_VERSION"
    fi
}

# Section title within a step
ui_section() {
    if _gum_present; then
        gum style --foreground 212 --bold --margin "1 2" "$1"
    else
        printf "\n${_c_mag}── %s${_c_rst}\n" "$1"
    fi
}

# Neutral informational line
ui_info() {
    if _gum_present; then
        gum style --foreground 81 --margin "0 2" "$1"
    else
        printf "  ${_c_cyn}→${_c_rst} %s\n" "$1"
    fi
}

# Confirmation that a step succeeded
ui_ok() {
    if _gum_present; then
        gum style --foreground 82 "  ✓ $1"
    else
        printf "  ${_c_grn}✓${_c_rst} %s\n" "$1"
    fi
}

# Non-fatal problem
ui_warn() {
    if _gum_present; then
        gum style --foreground 214 "  ⚠ $1"
    else
        printf "  ${_c_yel}⚠${_c_rst} %s\n" "$1"
    fi
}

# Something went wrong
ui_err() {
    if _gum_present; then
        gum style --foreground 196 "  ✗ $1"
    else
        printf "  ${_c_red}✗${_c_rst} %s\n" "$1"
    fi
}

# Yes/No prompt — returns 0 for yes, 1 for no
ui_confirm() {
    if _gum_present; then
        gum confirm --affirmative "Yes" --negative "No" "$1"
    else
        local ans
        read -rp "  ${_c_cyn}$1 [y/N]${_c_rst} " ans
        [[ "${ans,,}" == "y" ]]
    fi
}

# Run a labelled step, print success on exit
ui_step() {
    local label="$1"; shift
    ui_info "$label"
    "$@"
    ui_ok "${label%...}"
}

# ────────────────────────────────────────────────────────────────────────────────
# ERROR HANDLING
# ────────────────────────────────────────────────────────────────────────────────

_trap_err() {
    local code=$? line=${1:-?} command=${2:-?}
    if _gum_present; then
        gum style --foreground 196 --bold --margin "1 2" \
            "❌ Installer crashed (exit $code) at line $line" \
            "   Command: $command"
        echo ""
        gum input --placeholder "Press Enter to exit..."
    else
        printf "\n${_c_red}Crash at line %s (exit %s): %s${_c_rst}\n" \
            "$line" "$code" "$command"
    fi
    exit "$code"
}

trap '_trap_err "$LINENO" "$BASH_COMMAND"' ERR

# ────────────────────────────────────────────────────────────────────────────────
# PREFLIGHT CHECKS
# ────────────────────────────────────────────────────────────────────────────────

require_root() {
    [[ ${EUID:-1} -eq 0 ]] && return
    printf "${_c_red}Error: must be run as root.${_c_rst}\n"
    printf "Run: sudo bash %s\n" "$0"
    exit 1
}

detect_boot_mode() {
    [[ -d /sys/firmware/efi/efivars ]] \
        && CFG[uefi]="yes" \
        || CFG[uefi]="no"
}

# Cached so repeated calls don't re-ping
_net_checked="no"
require_network() {
    [[ "$_net_checked" == "yes" ]] && return 0
    if ping -c 1 -W 3 archlinux.org &>/dev/null; then
        _net_checked="yes"
        return 0
    fi
    printf "${_c_red}Error: no internet connection detected.${_c_rst}\n"
    exit 1
}

require_arch_iso() {
    [[ -f /etc/arch-release ]] && return
    printf "${_c_red}Error: must be run from the Arch Linux live ISO.${_c_rst}\n"
    exit 1
}

bootstrap_deps() {
    local missing=()
    command -v gum        &>/dev/null || missing+=(gum)
    command -v parted     &>/dev/null || missing+=(parted)
    command -v arch-chroot &>/dev/null || missing+=(arch-install-scripts)
    command -v sgdisk     &>/dev/null || missing+=(gptfdisk)
    command -v mkfs.btrfs &>/dev/null || missing+=(btrfs-progs)
    command -v mkfs.fat   &>/dev/null || missing+=(dosfstools)
    command -v mkfs.ext4  &>/dev/null || missing+=(e2fsprogs)
    command -v cryptsetup &>/dev/null || missing+=(cryptsetup)

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf "${_c_cyn}Fetching missing tools: %s${_c_rst}\n" "${missing[*]}"
        # Remove stale lock if a previous run was interrupted
        rm -f /var/lib/pacman/db.lck
        pacman -Sy --noconfirm --noprogressbar "${missing[@]}" 2>&1
    fi
}

# ────────────────────────────────────────────────────────────────────────────────
# PACMAN HELPERS
# ────────────────────────────────────────────────────────────────────────────────

# Ensure ParallelDownloads is set to the configured value
pacman_set_parallel() {
    local conf="$1" n="${CFG[parallel_downloads]}"
    if grep -q '^#*ParallelDownloads' "$conf"; then
        sed -i "s/^#*ParallelDownloads.*/ParallelDownloads = $n/" "$conf"
    else
        sed -i '/^\[options\]/a ParallelDownloads = '"$n" "$conf"
    fi
}

# Toggle on useful pacman flags (idempotent)
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

# ────────────────────────────────────────────────────────────────────────────────
# CONFIGURATION MENUS
# ────────────────────────────────────────────────────────────────────────────────

menu_locales() {
    ui_header
    ui_section "🗺️  System Locales"
    echo ""
    ui_info "Choose your system locale"
    echo ""

    local locales=(
        "en_US.UTF-8" "en_GB.UTF-8" "de_DE.UTF-8" "fr_FR.UTF-8"
        "es_ES.UTF-8" "it_IT.UTF-8" "pt_BR.UTF-8" "pt_PT.UTF-8"
        "ru_RU.UTF-8" "ja_JP.UTF-8" "ko_KR.UTF-8" "zh_CN.UTF-8"
        "pl_PL.UTF-8" "nl_NL.UTF-8" "tr_TR.UTF-8" "sv_SE.UTF-8"
        "da_DK.UTF-8" "fi_FI.UTF-8" "nb_NO.UTF-8" "cs_CZ.UTF-8"
    )

    local picked=""
    picked=$(printf '%s\n' "${locales[@]}" \
        | gum filter --placeholder "Search locale..." --height 12) || true
    [[ -n "$picked" ]] && CFG[locale]="$picked" && ui_ok "Locale: $picked"

    echo ""
    ui_info "Choose keyboard layout"
    echo ""

    local layouts=(
        "us" "uk" "de" "fr" "es" "it" "pt-latin9" "br-abnt2"
        "ru" "pl" "cz" "hu" "se" "no" "dk" "fi" "nl" "jp106"
        "dvorak" "colemak"
    )

    local kb=""
    kb=$(printf '%s\n' "${layouts[@]}" \
        | gum choose --height 12 --header "Keyboard layout:") || true
    if [[ -n "$kb" ]]; then
        CFG[keyboard]="$kb"
        loadkeys "$kb" 2>/dev/null || true
        ui_ok "Keyboard: $kb"
    fi
    sleep 0.5
}

menu_partitioning() {
    ui_header
    ui_section "💾 Disk Configuration"
    echo ""

    local choice=""
    choice=$(printf '%s\n' \
        "Auto    │ Wipe entire disk (Recommended)" \
        "Manual  │ Choose existing partitions (dual-boot)" \
        | gum choose --height 4 --header "Partitioning mode:") || true

    if [[ "$choice" == "Manual"* ]]; then
        CFG[partition_mode]="manual"
        _manual_partition
    else
        CFG[partition_mode]="auto"
        _auto_partition
    fi
}

_manual_partition() {
    ui_header
    ui_section "💾 Manual Partitioning"
    echo ""
    gum style --foreground 226 --bold --margin "0 2" \
        "ℹ️  Assigned partitions will be formatted. Others untouched."
    echo ""
    gum style --foreground 245 --margin "0 2" \
        "$(lsblk -o NAME,SIZE,FSTYPE,LABEL,TYPE,MOUNTPOINT 2>/dev/null)"
    echo ""

    if ui_confirm "Launch cfdisk to create/modify partitions first?"; then
        local raw_disks=()
        while IFS= read -r ln; do [[ -n "$ln" ]] && raw_disks+=("$ln"); done \
            < <(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null \
                | { grep -E '^/dev/(sd|nvme|vd|mmcblk)' || true; } \
                | sed 's/  */ /g')
        if [[ ${#raw_disks[@]} -gt 0 ]]; then
            local d=""
            d=$(printf '%s\n' "${raw_disks[@]}" \
                | gum choose --height 10 --header "Disk to edit with cfdisk:") || true
            if [[ -n "$d" ]]; then
                local dev; dev=$(awk '{print $1}' <<< "$d")
                cfdisk "$dev" || true
                partprobe "$dev" || true; udevadm settle
            fi
        fi
    fi

    local parts=()
    while IFS= read -r ln; do [[ -n "$ln" ]] && parts+=("$ln"); done \
        < <(lsblk -lpno NAME,SIZE,FSTYPE,LABEL 2>/dev/null \
            | { grep -E '^/dev/(sd|nvme|vd|mmcblk)[^ ]*[0-9]' || true; } \
            | sed 's/  */ /g')

    [[ ${#parts[@]} -eq 0 ]] && {
        ui_err "No partitions found."
        gum input --placeholder "Press Enter..."
        return
    }

    # Boot / EFI
    echo ""
    [[ "${CFG[uefi]}" == "yes" ]] \
        && ui_info "Select EFI System Partition (ESP)" \
        || ui_info "Select boot partition (or skip)"
    echo ""

    local boot_list=("-- Skip --")
    for p in "${parts[@]}"; do boot_list+=("$p"); done

    local boot_pick=""
    boot_pick=$(printf '%s\n' "${boot_list[@]}" \
        | gum choose --height 14 --header "Boot/EFI partition:") || true

    if [[ "$boot_pick" == "-- Skip --" ]]; then
        CFG[boot_part]=""; CFG[reuse_efi]="no"
    else
        CFG[boot_part]=$(awk '{print $1}' <<< "$boot_pick")
        ui_ok "Boot/EFI: ${CFG[boot_part]}"
        if [[ "${CFG[uefi]}" == "yes" ]]; then
            echo ""
            local efi_action=""
            efi_action=$(printf '%s\n' \
                "Format  │ Wipe and format as FAT32" \
                "Reuse   │ Mount without formatting (dual-boot)" \
                | gum choose --height 4 --header "EFI partition action:") || true
            [[ "$efi_action" == "Reuse"* ]] \
                && CFG[reuse_efi]="yes" \
                || CFG[reuse_efi]="no"
        fi
    fi

    # Root
    echo ""
    ui_info "Select root partition"
    echo ""
    local root_pick=""
    root_pick=$(printf '%s\n' "${parts[@]}" \
        | gum choose --height 14 --header "Root (/) partition:") || true
    [[ -z "$root_pick" ]] && { ui_err "No root partition selected."; return; }
    CFG[root_part]=$(awk '{print $1}' <<< "$root_pick")
    ui_ok "Root: ${CFG[root_part]}"

    local pk
    pk=$(lsblk -no PKNAME "${CFG[root_part]}" 2>/dev/null | head -1)
    CFG[disk]="${pk:+/dev/$pk}"
    [[ -z "${CFG[disk]}" ]] && CFG[disk]="${CFG[root_part]}"

    _pick_filesystem
    _pick_encryption
    sleep 0.5
}

_auto_partition() {
    ui_header
    ui_section "💾 Disk Selection"
    echo ""
    gum style --foreground 196 --bold --margin "0 2" \
        "⚠️  WARNING: the selected disk will be completely erased!"
    echo ""

    local raw_disks=()
    while IFS= read -r ln; do [[ -n "$ln" ]] && raw_disks+=("$ln"); done \
        < <(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null \
            | { grep -E '^/dev/(sd|nvme|vd|mmcblk)' || true; } \
            | sed 's/  */ /g')

    [[ ${#raw_disks[@]} -eq 0 ]] && { ui_err "No suitable disks found."; exit 1; }

    local d=""
    d=$(printf '%s\n' "${raw_disks[@]}" \
        | gum choose --height 10 --header "Target disk:") || true
    if [[ -n "$d" ]]; then
        CFG[disk]=$(awk '{print $1}' <<< "$d")
        ui_ok "Disk: ${CFG[disk]}"
        echo ""
        gum style --foreground 245 --margin "0 2" \
            "$(lsblk "${CFG[disk]}" 2>/dev/null)"
    fi

    _pick_filesystem

    echo ""
    ui_info "Disk Encryption (LUKS2)"
    echo ""
    if ui_confirm "Enable full disk encryption?"; then
        CFG[encrypt]="yes"
        local p1="" p2=""
        p1=$(gum input --password --placeholder "Encryption password" --width 50) || true
        p2=$(gum input --password --placeholder "Confirm password"    --width 50) || true
        if [[ "$p1" == "$p2" && -n "$p1" ]]; then
            CFG[encrypt_password]="$p1"
            echo ""
            local scope=""
            scope=$(printf '%s\n' \
                "root      │ Encrypt root only (faster boot)" \
                "root+boot │ Encrypt root & boot (more secure)" \
                | gum choose --height 4 --header "Scope:") || true
            [[ "$scope" == "root+boot"* ]] \
                && CFG[encrypt_boot]="yes" \
                || CFG[encrypt_boot]="no"
            ui_ok "Encryption enabled"
        else
            ui_err "Passwords don't match — encryption disabled."
            CFG[encrypt]="no"; CFG[encrypt_boot]="no"; CFG[encrypt_password]=""
        fi
    else
        CFG[encrypt]="no"; CFG[encrypt_boot]="no"; CFG[encrypt_password]=""
    fi
    sleep 0.5
}

_pick_filesystem() {
    echo ""
    ui_info "Select filesystem"
    echo ""
    local fs=""
    fs=$(printf '%s\n' \
        "btrfs    │ CoW with snapshots (Recommended)" \
        "ext4     │ Traditional, reliable" \
        "xfs      │ High-performance" \
        | gum choose --height 5 --header "Filesystem:") || true
    if [[ -n "$fs" ]]; then
        CFG[filesystem]=$(awk '{print $1}' <<< "$fs")
        ui_ok "Filesystem: ${CFG[filesystem]}"
    fi
}

_pick_encryption() {
    echo ""
    if ui_confirm "Enable LUKS2 encryption on root partition?"; then
        CFG[encrypt]="yes"; CFG[encrypt_boot]="no"
        local p1="" p2=""
        p1=$(gum input --password --placeholder "Encryption password" --width 50) || true
        p2=$(gum input --password --placeholder "Confirm password"    --width 50) || true
        if [[ "$p1" == "$p2" && -n "$p1" ]]; then
            CFG[encrypt_password]="$p1"; ui_ok "Encryption enabled"
        else
            ui_err "Passwords don't match — encryption disabled."
            CFG[encrypt]="no"; CFG[encrypt_password]=""
        fi
    else
        CFG[encrypt]="no"; CFG[encrypt_boot]="no"; CFG[encrypt_password]=""
    fi
}

menu_swap() {
    ui_header
    ui_section "🔄 Swap Configuration"
    echo ""
    local s=""
    s=$(printf '%s\n' \
        "zram     │ Compressed RAM swap (Recommended)" \
        "file     │ Traditional swap file on disk" \
        "none     │ No swap" \
        | gum choose --height 5 --header "Swap type:") || true
    if [[ -n "$s" ]]; then
        CFG[swap]=$(awk '{print $1}' <<< "$s")
        ui_ok "Swap: ${CFG[swap]}"
        if [[ "${CFG[swap]}" == "zram" ]]; then
            echo ""
            local algo=""
            algo=$(printf '%s\n' \
                "zstd     │ Best compression (Recommended)" \
                "lz4      │ Fastest" \
                "lzo      │ Balanced" \
                | gum choose --height 5 --header "zram algorithm:") || true
            [[ -n "$algo" ]] \
                && CFG[swap_algo]=$(awk '{print $1}' <<< "$algo") \
                && ui_ok "Algorithm: ${CFG[swap_algo]}"
        fi
    fi
    sleep 0.5
}

menu_hostname() {
    ui_header
    ui_section "💻 Hostname"
    echo ""
    local h=""
    h=$(gum input \
        --placeholder "orbitos" \
        --value "${CFG[hostname]}" \
        --width 40 \
        --header "Hostname:") || true
    if [[ "$h" =~ ^[a-z][a-z0-9-]*$ && ${#h} -le 63 ]]; then
        CFG[hostname]="$h"
    else
        ui_warn "Invalid hostname — keeping default: orbitos"
        CFG[hostname]="orbitos"
    fi
    ui_ok "Hostname: ${CFG[hostname]}"
    sleep 0.5
}

menu_credentials() {
    ui_header
    ui_section "👤 User Account"
    echo ""

    local u=""
    u=$(gum input --placeholder "username" --width 40 \
        --header "Username (lowercase letters only):") || true
    if [[ ! "$u" =~ ^[a-z_][a-z0-9_-]*$ || ${#u} -gt 32 || -z "$u" ]]; then
        ui_warn "Invalid username — falling back to 'user'"
        u="user"
    fi
    CFG[username]="$u"
    ui_ok "Username: ${CFG[username]}"
    echo ""

    local p1="" p2=""
    p1=$(gum input --password --placeholder "Password for $u" --width 50) || true
    p2=$(gum input --password --placeholder "Confirm password"  --width 50) || true
    if [[ "$p1" == "$p2" && -n "$p1" ]]; then
        CFG[user_password]="$p1"
        ui_ok "User password set"
    else
        ui_err "Passwords don't match — please try again."
        sleep 1; menu_credentials; return
    fi

    echo ""
    ui_section "🔐 Root Password"
    echo ""
    if ui_confirm "Use the same password for root?"; then
        CFG[root_password]="${CFG[user_password]}"
        ui_ok "Root: same as user"
    else
        local r1="" r2=""
        r1=$(gum input --password --placeholder "Root password"         --width 50) || true
        r2=$(gum input --password --placeholder "Confirm root password" --width 50) || true
        if [[ "$r1" == "$r2" && -n "$r1" ]]; then
            CFG[root_password]="$r1"; ui_ok "Root password set"
        else
            ui_warn "Mismatch — using user password for root."
            CFG[root_password]="${CFG[user_password]}"
        fi
    fi
    sleep 0.5
}

menu_timezone() {
    ui_header
    ui_section "🕐 Timezone"
    echo ""

    local regions=""
    regions=$(find /usr/share/zoneinfo -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
              | grep -vE '^(\+|posix|right|zoneinfo)$' | sort) || true

    local region=""
    region=$(echo "$regions" \
        | gum filter --placeholder "Search region..." --height 12 \
            --header "Region:") || true

    if [[ -n "$region" ]]; then
        local cities=""
        cities=$(find "/usr/share/zoneinfo/$region" -type f -printf '%f\n' 2>/dev/null | sort) || true
        if [[ -n "$cities" ]]; then
            echo ""
            local city=""
            city=$(echo "$cities" \
                | gum filter --placeholder "Search city..." --height 12 \
                    --header "City:") || true
            [[ -n "$city" ]] \
                && CFG[timezone]="$region/$city" \
                || CFG[timezone]="$region"
        else
            CFG[timezone]="$region"
        fi
        ui_ok "Timezone: ${CFG[timezone]}"
    fi
    sleep 0.5
}

menu_parallel_downloads() {
    ui_header
    ui_section "⚡ Parallel Downloads"
    echo ""
    local s=""
    s=$(printf '%s\n' \
        "3      │ Conservative" \
        "5      │ Default (recommended)" \
        "10     │ Fast" \
        "15     │ Maximum" \
        | gum choose --height 6 --header "Parallel downloads:") || true
    [[ -n "$s" ]] \
        && CFG[parallel_downloads]=$(awk '{print $1}' <<< "$s") \
        && ui_ok "Parallel downloads: ${CFG[parallel_downloads]}"
    sleep 0.5
}

menu_aur_helper() {
    ui_header
    ui_section "🔧 AUR Helper"
    echo ""
    local s=""
    s=$(printf '%s\n' \
        "paru   │ Rust-based, feature-rich (Recommended)" \
        "yay    │ Go-based, widely used" \
        | gum choose --height 4 --header "AUR helper:") || true
    [[ -n "$s" ]] \
        && CFG[aur_helper]=$(awk '{print $1}' <<< "$s") \
        && ui_ok "AUR helper: ${CFG[aur_helper]}"
    sleep 0.5
}

menu_login_manager() {
    ui_header
    ui_section "🔐 Login Manager"
    echo ""
    local s=""
    s=$(printf '%s\n' \
        "sddm            │ Stable, widely used (Recommended)" \
        "plasma-login    │ New KDE-native manager" \
        | gum choose --height 4 --header "Login manager:") || true
    [[ -n "$s" ]] \
        && CFG[login_manager]=$(awk '{print $1}' <<< "$s") \
        && ui_ok "Login manager: ${CFG[login_manager]}"
    sleep 0.5
}

menu_cachyos_toggle() {
    ui_header
    ui_section "⚡ CachyOS Optimized Packages"
    echo ""
    gum style --foreground 245 --margin "0 2" \
        "CachyOS rebuilds core system packages (glibc, mesa, etc.)" \
        "with x86-64-v3/v4 instruction sets for modern CPUs." \
        "" \
        "Safe on any CPU from ~2013 onwards (Haswell+)." \
        "The installer auto-detects your CPU capability level."
    echo ""
    if ui_confirm "Enable CachyOS optimized packages?"; then
        CFG[cachyos_optimized]="yes"
        ui_ok "CachyOS optimized packages: enabled"
    else
        CFG[cachyos_optimized]="no"
        ui_ok "Using vanilla Arch packages"
    fi
    sleep 0.5
}

menu_handheld() {
    ui_header
    ui_section "🎮 Handheld Mode"
    echo ""
    gum style --foreground 245 --margin "0 2" \
        "Handheld mode replaces linux-zen with linux-bazzite-bin" \
        "and installs HHD (Handheld Daemon) for gamepad, gyro, and TDP control." \
        "" \
        "Supported: Steam Deck, ROG Ally, Legion Go, GPD Win, OneXPlayer, AYA NEO, etc." \
        "" \
        "inputplumber and steamos-manager will be masked; hhd will be enabled instead."
    echo ""
    if ui_confirm "Enable handheld mode?"; then
        CFG[handheld]="yes"
        ui_ok "Handheld mode: enabled (linux-bazzite-bin + HHD)"
    else
        CFG[handheld]="no"
        ui_ok "Handheld mode: disabled (linux-zen kernel)"
    fi
    sleep 0.5
}

menu_extra_packages() {
    ui_header
    ui_section "📦 Optional Packages"
    echo ""
    ui_info "Space to toggle, Enter to confirm"
    echo ""

    # Format: "pkgname  Description text"
    local catalogue=(
        "firefox            Web browser"
        "brave-bin          Brave browser"
        "librewolf          Privacy-focused browser"
        "discord            Discord"
        "vesktop            Discord (enhanced client)"
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

    local labels=()
    declare -A label_to_pkg
    for entry in "${catalogue[@]}"; do
        local pkg lbl
        pkg=$(awk '{print $1}' <<< "$entry")
        lbl=$(awk '{$1=""; print substr($0,2)}' <<< "$entry")
        local display="$pkg  — $lbl"
        labels+=("$display")
        label_to_pkg["$display"]="$pkg"
    done

    local selected=""
    selected=$(printf '%s\n' "${labels[@]}" \
        | gum choose --no-limit --height 20 \
            --header "Extra packages (space to select):") || true

    ADDON_PKGS=""
    while IFS= read -r line; do
        [[ -n "$line" ]] && ADDON_PKGS+=" ${label_to_pkg[$line]:-}"
    done <<< "$selected"
    ADDON_PKGS=$(xargs <<< "$ADDON_PKGS")

    if [[ -n "$ADDON_PKGS" ]]; then
        ui_ok "Selected: $ADDON_PKGS"
    else
        ui_info "No extra packages selected"
    fi
    sleep 0.5
}

# ────────────────────────────────────────────────────────────────────────────────
# VALIDATION & SUMMARY
# ────────────────────────────────────────────────────────────────────────────────

validate_config() {
    local problems=()

    if [[ "${CFG[partition_mode]}" == "manual" ]]; then
        [[ -z "${CFG[root_part]}" ]] && problems+=("Root partition not set")
        [[ -n "${CFG[root_part]}" && ! -b "${CFG[root_part]}" ]] \
            && problems+=("'${CFG[root_part]}' is not a block device")
        [[ -n "${CFG[boot_part]}" && ! -b "${CFG[boot_part]}" ]] \
            && problems+=("'${CFG[boot_part]}' is not a block device")
    else
        [[ -z "${CFG[disk]}" ]] && problems+=("No disk selected")
    fi

    [[ -z "${CFG[username]}" ]]      && problems+=("No user account configured")
    [[ -z "${CFG[user_password]}" ]] && problems+=("User password not set")
    [[ -z "${CFG[root_password]}" ]] && problems+=("Root password not set")

    if [[ ${#problems[@]} -gt 0 ]]; then
        ui_header
        gum style --foreground 196 --bold --margin "1 2" "❌ Configuration incomplete"
        echo ""
        for p in "${problems[@]}"; do ui_err "$p"; done
        echo ""
        gum input --placeholder "Press Enter to return to the menu..."
        return 1
    fi
    return 0
}

show_summary() {
    ui_header
    ui_section "📋 Installation Summary"
    echo ""

    local enc_label="No"
    [[ "${CFG[encrypt]}" == "yes" && "${CFG[encrypt_boot]}" == "yes" ]] && enc_label="Yes (root+boot)"
    [[ "${CFG[encrypt]}" == "yes" && "${CFG[encrypt_boot]}" != "yes" ]] && enc_label="Yes (root only)"

    local boot_label="BIOS/Legacy"
    [[ "${CFG[uefi]}" == "yes" ]] && boot_label="UEFI"

    local disk_label="${CFG[disk]:-N/A}"
    [[ "${CFG[partition_mode]}" == "manual" ]] \
        && disk_label="root=${CFG[root_part]} boot=${CFG[boot_part]:-none}"

    local cachyos_label="No (vanilla Arch)"
    [[ "${CFG[cachyos_optimized]}" == "yes" ]] && cachyos_label="Yes (x86-64-v3/v4)"

    local handheld_label="No (linux-zen)"
    [[ "${CFG[handheld]}" == "yes" ]] && handheld_label="Yes (linux-bazzite-bin + HHD)"

    gum style --border rounded --border-foreground 212 --padding "1 2" --margin "0 2" \
        "Locale:       ${CFG[locale]}" \
        "Keyboard:     ${CFG[keyboard]}" \
        "Timezone:     ${CFG[timezone]}" \
        "Hostname:     ${CFG[hostname]}" \
        "Username:     ${CFG[username]}" \
        "" \
        "Disk:         $disk_label" \
        "Partition:    ${CFG[partition_mode]}" \
        "Filesystem:   ${CFG[filesystem]}" \
        "Encryption:   $enc_label" \
        "Swap:         ${CFG[swap]}" \
        "" \
        "Graphics:     Auto-detect (chwd)" \
        "Optimized:    $cachyos_label" \
        "Handheld:     $handheld_label" \
        "Boot mode:    $boot_label" \
        "AUR helper:   ${CFG[aur_helper]}" \
        "Login mgr:    ${CFG[login_manager]}" \
        "Downloads:    ${CFG[parallel_downloads]} parallel" \
        "Extra pkgs:   ${ADDON_PKGS:-none}"
    echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# MAIN MENU
# ────────────────────────────────────────────────────────────────────────────────

run_main_menu() {
    while true; do
        ui_header

        local boot_mode="BIOS"
        [[ "${CFG[uefi]}" == "yes" ]] && boot_mode="UEFI"
        gum style --foreground 245 --margin "0 2" "Boot mode: $boot_mode"
        echo ""

        local disk_status="${CFG[disk]:-Not configured}"
        [[ "${CFG[partition_mode]}" == "manual" && -n "${CFG[root_part]}" ]] \
            && disk_status="Manual: root=${CFG[root_part]}"

        local cachyos_status="no"
        [[ "${CFG[cachyos_optimized]}" == "yes" ]] \
            && cachyos_status="yes (x86-64-v3/v4)"

        local handheld_status="no"
        [[ "${CFG[handheld]}" == "yes" ]] \
            && handheld_status="yes (linux-bazzite-bin + HHD)"

        local entries=(
            ""
            "1.  🗺️  Locales            │ ${CFG[locale]} / ${CFG[keyboard]}"
            "2.  💾 Disk               │ $disk_status (${CFG[filesystem]})"
            "3.  🔄 Swap               │ ${CFG[swap]}"
            "4.  💻 Hostname           │ ${CFG[hostname]}"
            "5.  👤 Credentials        │ ${CFG[username]:-Not configured}"
            "6.  🕐 Timezone           │ ${CFG[timezone]}"
            "7.  ⚡ Parallel DLs       │ ${CFG[parallel_downloads]}"
            "8.  🔧 AUR Helper         │ ${CFG[aur_helper]}"
            "9.  🔐 Login Manager      │ ${CFG[login_manager]}"
            "10. 🚀 CachyOS Optimized  │ $cachyos_status"
            "11. 📦 Extra Packages     │ ${ADDON_PKGS:-none}"
            "12. 🎮 Handheld Mode      │ $handheld_status"
            "──────────────────────────────────────────────"
            "13. ✅ Begin Installation"
            "0.  ❌ Exit"
        )

        local choice=""
        choice=$(printf '%s\n' "${entries[@]}" \
            | gum choose --height 20 \
                --header $'Configure your installation:\n') || true

        case "$choice" in
            "1."*)  menu_locales ;;
            "2."*)  menu_partitioning ;;
            "3."*)  menu_swap ;;
            "4."*)  menu_hostname ;;
            "5."*)  menu_credentials ;;
            "6."*)  menu_timezone ;;
            "7."*)  menu_parallel_downloads ;;
            "8."*)  menu_aur_helper ;;
            "9."*)  menu_login_manager ;;
            "10."*) menu_cachyos_toggle ;;
            "11."*) menu_extra_packages ;;
            "12."*) menu_handheld ;;
            "13."*)
                if validate_config; then
                    show_summary
                    local prompt="THIS WILL ERASE ${CFG[disk]}. Continue?"
                    [[ "${CFG[partition_mode]}" == "manual" ]] \
                        && prompt="${CFG[root_part]} will be formatted as root. Continue?"
                    if ui_confirm "$prompt"; then
                        perform_installation
                        break
                    fi
                fi
                ;;
            "0."*)
                ui_confirm "Exit installer?" && { echo "Cancelled."; exit 0; }
                ;;
        esac
    done
}

# ────────────────────────────────────────────────────────────────────────────────
# DISK OPERATIONS
# ────────────────────────────────────────────────────────────────────────────────

partition_disk() {
    [[ "${CFG[partition_mode]}" == "manual" ]] && return 0

    local disk="${CFG[disk]}"
    [[ -n "$disk" ]] || { echo "ERROR: CFG[disk] is empty"; exit 1; }

    wipefs -af "$disk" 2>/dev/null || true
    sgdisk -Z "$disk" &>/dev/null || true

    if [[ "${CFG[uefi]}" == "yes" ]]; then
        parted -s "$disk" mklabel gpt
        parted -s "$disk" mkpart ESP fat32 1MiB 2049MiB
        parted -s "$disk" set 1 esp on
        parted -s "$disk" mkpart primary 2049MiB 100%
    elif [[ "${CFG[encrypt]}" == "yes" && "${CFG[encrypt_boot]}" == "yes" ]]; then
        parted -s "$disk" mklabel msdos
        parted -s "$disk" mkpart primary 1MiB 100%
    else
        parted -s "$disk" mklabel msdos
        parted -s "$disk" mkpart primary ext4 1MiB 2049MiB
        parted -s "$disk" set 1 boot on
        parted -s "$disk" mkpart primary 2049MiB 100%
    fi

    partprobe "$disk" || true; udevadm settle; sleep 1

    if [[ "${CFG[encrypt]}" == "yes" && "${CFG[encrypt_boot]}" == "yes" && "${CFG[uefi]}" != "yes" ]]; then
        CFG[boot_part]=""
        [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]] \
            && CFG[root_part]="${disk}p1" \
            || CFG[root_part]="${disk}1"
    else
        [[ "$disk" == *nvme* || "$disk" == *mmcblk* ]] \
            && { CFG[boot_part]="${disk}p1"; CFG[root_part]="${disk}p2"; } \
            || { CFG[boot_part]="${disk}1";  CFG[root_part]="${disk}2"; }
    fi

    [[ -n "${CFG[boot_part]}" && ! -b "${CFG[boot_part]}" ]] \
        && { echo "ERROR: boot_part not ready"; exit 1; }
    [[ -b "${CFG[root_part]}" ]] \
        || { echo "ERROR: root_part not ready"; lsblk -f "$disk"; exit 1; }
}

setup_encryption() {
    [[ "${CFG[encrypt]}" == "yes" ]] || return 0
    [[ -n "${CFG[encrypt_password]}" ]] || { echo "ERROR: encrypt_password is empty"; exit 1; }
    [[ -b "${CFG[root_part]}" ]]        || { echo "ERROR: root_part is not a block device"; exit 1; }

    echo -n "${CFG[encrypt_password]}" \
        | cryptsetup luksFormat --type luks2 "${CFG[root_part]}" -
    echo -n "${CFG[encrypt_password]}" \
        | cryptsetup open "${CFG[root_part]}" cryptroot -
    CFG[root_device]="/dev/mapper/cryptroot"
    [[ -b "${CFG[root_device]}" ]] \
        || { echo "ERROR: cryptroot mapper not created"; exit 1; }
}

format_partitions() {
    local root_dev="${CFG[root_part]}"
    [[ "${CFG[encrypt]}" == "yes" ]] && root_dev="${CFG[root_device]}"
    [[ -b "$root_dev" ]] || { echo "ERROR: root device '$root_dev' is not a block device"; exit 1; }

    if [[ -n "${CFG[boot_part]}" ]]; then
        [[ -b "${CFG[boot_part]}" ]] || { echo "ERROR: boot_part is not a block device"; exit 1; }
        if [[ "${CFG[reuse_efi]}" == "yes" ]]; then
            echo "Reusing existing EFI — skipping format"
        elif [[ "${CFG[uefi]}" == "yes" ]]; then
            wipefs -af "${CFG[boot_part]}" &>/dev/null
            mkfs.fat -F32 "${CFG[boot_part]}"
        else
            wipefs -af "${CFG[boot_part]}" &>/dev/null
            mkfs.ext4 -F "${CFG[boot_part]}"
        fi
    fi

    wipefs -af "$root_dev" &>/dev/null
    case "${CFG[filesystem]}" in
        btrfs) mkfs.btrfs -f "$root_dev" ;;
        ext4)  mkfs.ext4  -F "$root_dev" ;;
        xfs)   mkfs.xfs   -f "$root_dev" ;;
        *)     echo "ERROR: unknown filesystem '${CFG[filesystem]}'"; exit 1 ;;
    esac
}

mount_filesystems() {
    local root_dev="${CFG[root_part]}"
    [[ "${CFG[encrypt]}" == "yes" ]] && root_dev="${CFG[root_device]}"
    [[ -b "$root_dev" ]] || { echo "ERROR: root device is not a block device"; exit 1; }

    if [[ "${CFG[filesystem]}" == "btrfs" ]]; then
        mount "$root_dev" "$ORBIT_MOUNT"
        btrfs subvolume create "$ORBIT_MOUNT/@"
        btrfs subvolume create "$ORBIT_MOUNT/@home"
        btrfs subvolume create "$ORBIT_MOUNT/@var"
        btrfs subvolume create "$ORBIT_MOUNT/@tmp"
        btrfs subvolume create "$ORBIT_MOUNT/@snapshots"
        umount "$ORBIT_MOUNT"
        mount -o noatime,compress=zstd,subvol=@ "$root_dev" "$ORBIT_MOUNT"
        mkdir -p "$ORBIT_MOUNT"/{home,var,tmp,.snapshots,boot}
        mount -o noatime,compress=zstd,subvol=@home "$root_dev" "$ORBIT_MOUNT/home"
        mount -o noatime,compress=zstd,subvol=@var  "$root_dev" "$ORBIT_MOUNT/var"
        mount -o noatime,compress=zstd,subvol=@tmp  "$root_dev" "$ORBIT_MOUNT/tmp"
        mount -o noatime,compress=zstd,subvol=@snapshots "$root_dev" "$ORBIT_MOUNT/.snapshots"
    else
        mount "$root_dev" "$ORBIT_MOUNT"
        mkdir -p "$ORBIT_MOUNT/boot"
    fi

    if [[ "${CFG[uefi]}" == "yes" && -n "${CFG[boot_part]}" ]]; then
        if [[ "${CFG[encrypt]}" == "yes" && "${CFG[encrypt_boot]}" == "no" ]]; then
            mkdir -p "$ORBIT_MOUNT/boot"
            mount "${CFG[boot_part]}" "$ORBIT_MOUNT/boot"
        else
            mkdir -p "$ORBIT_MOUNT/boot/efi"
            mount "${CFG[boot_part]}" "$ORBIT_MOUNT/boot/efi"
        fi
    elif [[ -n "${CFG[boot_part]}" ]]; then
        mount "${CFG[boot_part]}" "$ORBIT_MOUNT/boot"
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

    pacman_set_parallel /etc/pacman.conf
    pacman_set_opts     /etc/pacman.conf
    pacman -Sy --noconfirm
}

install_base_system() {
    add_temp_repo

    # linux-zen is always used as the pacstrap kernel.
    # In handheld mode it will be replaced by linux-bazzite-bin after
    # repos are configured (install_handheld_kernel runs later).
    local pkgs="base base-devel linux-zen linux-zen-headers"

    grep -q "GenuineIntel" /proc/cpuinfo && pkgs+=" intel-ucode"
    grep -q "AuthenticAMD" /proc/cpuinfo && pkgs+=" amd-ucode"

    pkgs+=" grub efibootmgr os-prober"
    pkgs+=" btrfs-progs dosfstools e2fsprogs xfsprogs gptfdisk"
    pkgs+=" sudo nano vim git wget curl"
    pkgs+=" networkmanager iw iwd ppp openssh wpa_supplicant wireless_tools"
    pkgs+=" avahi nss-mdns dhcpcd"
    pkgs+=" bluez bluez-libs bluez-utils"
    pkgs+=" pipewire wireplumber pipewire-jack pipewire-alsa pipewire-pulse"
    pkgs+=" alsa-utils alsa-plugins alsa-firmware"
    pkgs+=" gstreamer gst-libav gst-plugins-good gst-plugins-bad gst-plugin-pipewire"
    pkgs+=" cups"
    pkgs+=" xorg-server xorg-xwayland xorg-xinit"
    pkgs+=" fwupd sof-firmware linux-firmware"

    pacstrap -K "$ORBIT_MOUNT" $pkgs
    genfstab -U "$ORBIT_MOUNT" >> "$ORBIT_MOUNT/etc/fstab"
}

add_repos() {
    sed -i '/^#\[multilib\]/{N;s/#\[multilib\]\n#Include/[multilib]\nInclude/}' \
        "$ORBIT_MOUNT/etc/pacman.conf"

    if ! grep -q "\[chaotic-aur\]" "$ORBIT_MOUNT/etc/pacman.conf"; then
        arch-chroot "$ORBIT_MOUNT" pacman-key --recv-key 3056513887B78AEB \
            --keyserver keyserver.ubuntu.com
        arch-chroot "$ORBIT_MOUNT" pacman-key --lsign-key 3056513887B78AEB
        arch-chroot "$ORBIT_MOUNT" pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
        arch-chroot "$ORBIT_MOUNT" pacman -U --noconfirm \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
        echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' \
            >> "$ORBIT_MOUNT/etc/pacman.conf"
    fi

    if ! grep -q "\[cachyos\]" "$ORBIT_MOUNT/etc/pacman.conf"; then
        ui_info "  Adding CachyOS repository..."
        arch-chroot "$ORBIT_MOUNT" bash -c '
            set -e
            cd /tmp
            curl -sSL https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
            tar xf cachyos-repo.tar.xz
            cd cachyos-repo
            yes | ./cachyos-repo.sh
            rm -rf /tmp/cachyos-repo /tmp/cachyos-repo.tar.xz
        ' || ui_warn "cachyos-repo.sh reported errors — CachyOS packages may not be available"
    fi

    pacman_set_parallel "$ORBIT_MOUNT/etc/pacman.conf"
    pacman_set_opts     "$ORBIT_MOUNT/etc/pacman.conf"
    arch-chroot "$ORBIT_MOUNT" pacman -Syy --noconfirm

    # ── Verify CachyOS repo is functional ─────────────────────────────────
    if arch-chroot "$ORBIT_MOUNT" pacman -Si cachyos-gaming-meta &>/dev/null; then
        ui_ok "CachyOS repository verified"
    else
        ui_warn "CachyOS repo may not be fully configured — retrying sync..."
        arch-chroot "$ORBIT_MOUNT" pacman -Syy --noconfirm
        if arch-chroot "$ORBIT_MOUNT" pacman -Si cachyos-gaming-meta &>/dev/null; then
            ui_ok "CachyOS repository verified on retry"
        else
            ui_warn "CachyOS packages not found — gaming meta and chwd may fail"
        fi
    fi
}

configure_system() {
    arch-chroot "$ORBIT_MOUNT" ln -sf \
        "/usr/share/zoneinfo/${CFG[timezone]}" /etc/localtime
    arch-chroot "$ORBIT_MOUNT" hwclock --systohc

    echo "${CFG[locale]} UTF-8" >> "$ORBIT_MOUNT/etc/locale.gen"
    echo "en_US.UTF-8 UTF-8"    >> "$ORBIT_MOUNT/etc/locale.gen"
    arch-chroot "$ORBIT_MOUNT" locale-gen
    echo "LANG=${CFG[locale]}"     > "$ORBIT_MOUNT/etc/locale.conf"
    echo "KEYMAP=${CFG[keyboard]}" > "$ORBIT_MOUNT/etc/vconsole.conf"

    echo "${CFG[hostname]}" > "$ORBIT_MOUNT/etc/hostname"
    cat > "$ORBIT_MOUNT/etc/hosts" << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${CFG[hostname]}.localdomain ${CFG[hostname]}
EOF

    arch-chroot "$ORBIT_MOUNT" systemctl enable NetworkManager avahi-daemon

    mkdir -p "$ORBIT_MOUNT/etc/NetworkManager/conf.d"
    cat > "$ORBIT_MOUNT/etc/NetworkManager/conf.d/wifi-backend.conf" << 'EOF'
[device]
wifi.backend=wpa_supplicant
EOF

    if [[ "${CFG[encrypt]}" == "yes" ]]; then
        sed -i \
            's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' \
            "$ORBIT_MOUNT/etc/mkinitcpio.conf"
        arch-chroot "$ORBIT_MOUNT" mkinitcpio -P
    fi
}

install_bootloader() {
    local efi_dir="/boot/efi"

    if [[ "${CFG[uefi]}" == "yes" ]]; then
        [[ "${CFG[encrypt]}" == "yes" && "${CFG[encrypt_boot]}" == "no" ]] \
            && efi_dir="/boot" \
            || efi_dir="/boot/efi"
        mkdir -p "$ORBIT_MOUNT$efi_dir"
        mountpoint -q "$ORBIT_MOUNT$efi_dir" \
            || mount "${CFG[boot_part]}" "$ORBIT_MOUNT$efi_dir"

        if [[ "${CFG[encrypt_boot]}" == "yes" && "${CFG[encrypt]}" == "yes" ]]; then
            grep -q '^GRUB_ENABLE_CRYPTODISK=' "$ORBIT_MOUNT/etc/default/grub" \
                && sed -i 's/^GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' \
                    "$ORBIT_MOUNT/etc/default/grub" \
                || echo 'GRUB_ENABLE_CRYPTODISK=y' >> "$ORBIT_MOUNT/etc/default/grub"
            arch-chroot "$ORBIT_MOUNT" grub-install \
                --target=x86_64-efi --efi-directory="$efi_dir" \
                --bootloader-id=OrbitOS --removable --recheck \
                --modules="part_gpt part_msdos luks2 cryptodisk gcry_rijndael gcry_sha256"
        else
            arch-chroot "$ORBIT_MOUNT" grub-install \
                --target=x86_64-efi --efi-directory="$efi_dir" \
                --bootloader-id=OrbitOS --removable --recheck
        fi
    else
        if [[ "${CFG[encrypt_boot]}" == "yes" && "${CFG[encrypt]}" == "yes" ]]; then
            grep -q '^GRUB_ENABLE_CRYPTODISK=' "$ORBIT_MOUNT/etc/default/grub" \
                && sed -i 's/^GRUB_ENABLE_CRYPTODISK=.*/GRUB_ENABLE_CRYPTODISK=y/' \
                    "$ORBIT_MOUNT/etc/default/grub" \
                || echo 'GRUB_ENABLE_CRYPTODISK=y' >> "$ORBIT_MOUNT/etc/default/grub"
            arch-chroot "$ORBIT_MOUNT" grub-install \
                --target=i386-pc --recheck \
                --modules="part_msdos luks2 cryptodisk gcry_rijndael gcry_sha256" \
                "${CFG[disk]}"
        else
            arch-chroot "$ORBIT_MOUNT" grub-install \
                --target=i386-pc "${CFG[disk]}"
        fi
    fi

    sed -i \
        's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 nvme_load=yes"/' \
        "$ORBIT_MOUNT/etc/default/grub"
    sed -i \
        's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="OrbitOS"/' \
        "$ORBIT_MOUNT/etc/default/grub"
    sed -i \
        's/^#*GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' \
        "$ORBIT_MOUNT/etc/default/grub"

    if [[ "${CFG[encrypt]}" == "yes" ]]; then
        local uuid
        uuid=$(blkid -s UUID -o value "${CFG[root_part]}")
        sed -i \
            "s|^GRUB_CMDLINE_LINUX=.*|GRUB_CMDLINE_LINUX=\"rd.luks.name=${uuid}=cryptroot root=/dev/mapper/cryptroot\"|" \
            "$ORBIT_MOUNT/etc/default/grub"
    fi

    arch-chroot "$ORBIT_MOUNT" grub-mkconfig -o /boot/grub/grub.cfg
}

create_user() {
    echo "root:${CFG[root_password]}" | arch-chroot "$ORBIT_MOUNT" chpasswd

    local groups="sys network scanner power cups realtime rfkill lp users video storage kvm optical audio wheel adm"
    for g in $groups; do
        arch-chroot "$ORBIT_MOUNT" groupadd -f "$g" 2>/dev/null || true
    done

    arch-chroot "$ORBIT_MOUNT" useradd -m \
        -G sys,network,scanner,power,cups,realtime,rfkill,lp,users,video,storage,kvm,optical,audio,wheel,adm \
        -s /bin/bash "${CFG[username]}"
    echo "${CFG[username]}:${CFG[user_password]}" | arch-chroot "$ORBIT_MOUNT" chpasswd
    sed -i \
        's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' \
        "$ORBIT_MOUNT/etc/sudoers"
}

# ────────────────────────────────────────────────────────────────────────────────
# AUR HELPER (standalone — called early so handheld kernel swap can use it)
# ────────────────────────────────────────────────────────────────────────────────

install_aur_helper() {
    ui_info "Installing AUR helper (${CFG[aur_helper]})..."
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed "${CFG[aur_helper]}" \
        || ui_warn "AUR helper install failed — install manually after reboot"
    ui_ok "AUR helper: ${CFG[aur_helper]}"
}

# ────────────────────────────────────────────────────────────────────────────────
# HARDWARE DRIVERS (chwd)
# ────────────────────────────────────────────────────────────────────────────────

install_drivers_chwd() {
    ui_info "  Verifying kernel state..."

    # In handheld mode linux-zen was already swapped out; only enforce it on
    # non-handheld installs where zen is expected to be the active kernel.
    if [[ "${CFG[handheld]}" != "yes" ]]; then
        local stray=""
        stray=$(arch-chroot "$ORBIT_MOUNT" pacman -Qqs '^linux-cachyos' 2>/dev/null || true)
        if [[ -n "$stray" ]]; then
            ui_warn "Unexpected CachyOS kernels found — removing to avoid conflicts: $stray"
            arch-chroot "$ORBIT_MOUNT" pacman -Rdd --noconfirm $stray 2>/dev/null || true
        fi
        arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed linux-zen linux-zen-headers
        ui_ok "Kernel: linux-zen + linux-zen-headers"
    else
        ui_ok "Kernel: linux-bazzite-bin (handheld mode)"
    fi

    ui_info "  Installing chwd hardware detector..."
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed chwd \
        || { ui_warn "chwd install failed — install drivers manually after reboot."; return 0; }
    ui_ok "chwd installed"

    ui_info "  Running hardware auto-detection..."
    arch-chroot "$ORBIT_MOUNT" chwd -a -f \
        || { ui_warn "chwd auto-detection failed — install drivers manually after reboot."; return 0; }
    ui_ok "Hardware drivers installed via chwd"

    # If NVIDIA modules were injected by chwd, add the required kernel parameters
    if [[ -f "$ORBIT_MOUNT/etc/mkinitcpio.conf.d/10-chwd.conf" ]] \
       && grep -q 'nvidia' "$ORBIT_MOUNT/etc/mkinitcpio.conf.d/10-chwd.conf" 2>/dev/null; then
        ui_info "  NVIDIA detected — patching GRUB kernel parameters..."
        local cmdline
        cmdline=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$ORBIT_MOUNT/etc/default/grub" \
            | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT="//;s/"$//')

        local extra=""
        [[ "$cmdline" != *"nvidia_drm.modeset=1"* ]] && extra+=" nvidia_drm.modeset=1"
        [[ "$cmdline" != *"nvidia_drm.fbdev=1"* ]]   && extra+=" nvidia_drm.fbdev=1"

        if [[ -n "$extra" ]]; then
            sed -i \
                "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1${extra}\"|" \
                "$ORBIT_MOUNT/etc/default/grub"
        fi

        arch-chroot "$ORBIT_MOUNT" grub-mkconfig -o /boot/grub/grub.cfg
        ui_ok "NVIDIA kernel parameters applied"
    fi

    arch-chroot "$ORBIT_MOUNT" mkinitcpio -P
    ui_ok "Initramfs rebuilt"

    # ── Handheld post-chwd services ─────────────────────────────────────────
    setup_handheld_services
}

# ────────────────────────────────────────────────────────────────────────────────
# HANDHELD KERNEL + SERVICES
# ────────────────────────────────────────────────────────────────────────────────

# Called after add_repos + create_user + install_aur_helper: swaps linux-zen
# for linux-bazzite-bin when handheld mode is enabled.  linux-zen is kept
# during pacstrap so the chroot is always in a bootable state while the
# installation proceeds.
#
# Requires: user account and AUR helper already present in the chroot
# (linux-bazzite-bin is NOT in Chaotic-AUR so the AUR helper is the
# primary install path).
install_handheld_kernel() {
    [[ "${CFG[handheld]}" == "yes" ]] || return 0

    ui_info "  Installing Bazzite kernel (linux-bazzite-bin)..."

    # linux-bazzite-bin is an AUR package; try the AUR helper first since
    # that is the expected path, then fall back to a direct pacman attempt
    # in case it ever lands in a configured repo.
    local bazzite_installed="no"

    if arch-chroot "$ORBIT_MOUNT" su -l "${CFG[username]}" -c \
            "${CFG[aur_helper]} -S --noconfirm --needed linux-bazzite-bin" \
            2>/dev/null; then
        bazzite_installed="yes"
        ui_ok "linux-bazzite-bin installed via ${CFG[aur_helper]}"
    else
        ui_info "  AUR build failed — trying pacman repos as fallback..."
        if arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
                linux-bazzite-bin 2>/dev/null; then
            bazzite_installed="yes"
            ui_ok "linux-bazzite-bin installed via pacman"
        fi
    fi

    if [[ "$bazzite_installed" != "yes" ]]; then
        ui_warn "Bazzite kernel install failed — keeping linux-zen as fallback."
        CFG[handheld]="no"
        return 0
    fi

    # Remove linux-zen now that bazzite is in place.
    # -Rdd skips dependency checks so grub/mkinitcpio hooks don't fire mid-swap.
    ui_info "  Removing linux-zen..."
    arch-chroot "$ORBIT_MOUNT" pacman -Rdd --noconfirm linux-zen linux-zen-headers 2>/dev/null \
        || ui_warn "linux-zen removal had errors — may need manual cleanup after reboot"
    ui_ok "linux-zen removed"

    # Rebuild initramfs for the new kernel and regenerate the GRUB config so
    # the bazzite vmlinuz/initrd paths are picked up correctly.
    ui_info "  Rebuilding initramfs and GRUB config for Bazzite kernel..."
    arch-chroot "$ORBIT_MOUNT" mkinitcpio -P
    arch-chroot "$ORBIT_MOUNT" grub-mkconfig -o /boot/grub/grub.cfg
    ui_ok "Bazzite kernel is now the active boot target"
}

# Called at the end of install_drivers_chwd when handheld mode is active.
# Installs hhd + hhd-ui from CachyOS/Chaotic repos, masks the conflicting
# inputplumber and steamos-manager units, then enables the per-user hhd service.
setup_handheld_services() {
    [[ "${CFG[handheld]}" == "yes" ]] || return 0

    ui_info "  Installing HHD and HHD-UI..."
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed hhd hhd-ui \
        || {
            ui_warn "HHD install failed — install manually after reboot: sudo pacman -S hhd hhd-ui"
            return 0
        }
    ui_ok "hhd + hhd-ui installed"

    ui_info "  Masking conflicting services (inputplumber, steamos-manager)..."
    arch-chroot "$ORBIT_MOUNT" systemctl mask inputplumber    2>/dev/null || true
    arch-chroot "$ORBIT_MOUNT" systemctl mask steamos-manager 2>/dev/null || true
    ui_ok "inputplumber and steamos-manager masked"

    ui_info "  Enabling hhd@${CFG[username]}..."
    arch-chroot "$ORBIT_MOUNT" systemctl enable "hhd@${CFG[username]}" \
        || ui_warn "Could not enable hhd — run after reboot: sudo systemctl enable hhd@\$(whoami)"
    ui_ok "hhd@${CFG[username]} enabled"
}

# ────────────────────────────────────────────────────────────────────────────────
# SWAP
# ────────────────────────────────────────────────────────────────────────────────

setup_swap_system() {
    case "${CFG[swap]}" in
        zram)
            arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm zram-generator
            cat > "$ORBIT_MOUNT/etc/systemd/zram-generator.conf" << EOF
[zram0]
zram-size = ram / 2
compression-algorithm = ${CFG[swap_algo]}
EOF
            ;;
        file)
            if [[ "${CFG[filesystem]}" == "btrfs" ]]; then
                arch-chroot "$ORBIT_MOUNT" truncate -s 0 /swapfile
                arch-chroot "$ORBIT_MOUNT" chattr +C /swapfile
                arch-chroot "$ORBIT_MOUNT" fallocate -l 4G /swapfile
            else
                arch-chroot "$ORBIT_MOUNT" dd \
                    if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
            fi
            arch-chroot "$ORBIT_MOUNT" chmod 600 /swapfile
            arch-chroot "$ORBIT_MOUNT" mkswap /swapfile
            echo "/swapfile none swap defaults 0 0" >> "$ORBIT_MOUNT/etc/fstab"
            ;;
        none) ;;
    esac
}

# ────────────────────────────────────────────────────────────────────────────────
# KDE PLASMA DESKTOP
# ────────────────────────────────────────────────────────────────────────────────
#

install_kde_minimal() {
    ui_info "Installing KDE Plasma desktop..."

    # ── Plasma meta — full upstream-tested desktop ────────────────────────
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
        plasma-meta

    # ── NVIDIA Wayland support (not in plasma-meta) ─────────────────────
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
        egl-wayland

    # ── KDE applications ─────────────────────────────────────────────────
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
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

    # ── Thumbnail / file previews ────────────────────────────────────────
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
        tumbler ffmpegthumbnailer poppler-qt6 \
        kdegraphics-thumbnailers

    # ── System utilities ─────────────────────────────────────────────────
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
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

    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
        ttf-hack-nerd ttf-jetbrains-mono-nerd \
        ttf-ubuntu-font-family adobe-source-sans-fonts \
        noto-fonts noto-fonts-emoji

    # AUR helper is already installed (install_aur_helper ran earlier).
    # --needed ensures this is a harmless no-op if already present.
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed "${CFG[aur_helper]}" 2>/dev/null || true

    case "${CFG[login_manager]}" in
        plasma-login)
            arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed plasma-login-manager
            arch-chroot "$ORBIT_MOUNT" systemctl enable plasmalogin.service
            ;;
        *)
            arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed sddm
            arch-chroot "$ORBIT_MOUNT" systemctl enable sddm.service
            ;;
    esac

    if [[ -n "$ADDON_PKGS" ]]; then
        ui_info "Installing extra packages: $ADDON_PKGS"
        arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed $ADDON_PKGS \
            || ui_warn "Some extra packages failed — install manually after reboot"
    fi

    # tuned-ppd provides a power-profiles-daemon compatibility layer;
    # enable tuned-ppd directly rather than the old unit name.
    arch-chroot "$ORBIT_MOUNT" systemctl enable \
        cups.socket \
        bluetooth \
        tuned \
        tuned-ppd \
        switcheroo-control \
        wpa_supplicant

    arch-chroot "$ORBIT_MOUNT" systemctl disable iwd    2>/dev/null || true
    arch-chroot "$ORBIT_MOUNT" systemctl disable dhcpcd 2>/dev/null || true

    arch-chroot "$ORBIT_MOUNT" su -l "${CFG[username]}" \
        -c "xdg-user-dirs-update" 2>/dev/null || true

    local bashrc="$ORBIT_MOUNT/home/${CFG[username]}/.bashrc"
    if ! grep -qF "fastfetch" "$bashrc" 2>/dev/null; then
        printf '\n# OrbitOS: system info on terminal open\nfastfetch\n' >> "$bashrc"
    fi
    arch-chroot "$ORBIT_MOUNT" chown "${CFG[username]}:${CFG[username]}" \
        "/home/${CFG[username]}/.bashrc" 2>/dev/null || true

    ui_ok "KDE Plasma desktop installed"
}

# ────────────────────────────────────────────────────────────────────────────────
# DISTRO BRANDING — KDE System Settings logo + kcm-about-distroinfo
# ────────────────────────────────────────────────────────────────────────────────
#
# Installs the OrbitOS logo to /usr/share/pixmaps/orbitos.png and wires it
# into both os-release (LOGO=orbitos) and the KDE About This System panel
# via kcm-about-distroinfo + /etc/xdg/kcm-about-distrorc.
#
# Logo source priority:
#   1. $ORBIT_LOGO_URL   — direct URL you set at the top of this script
#   2. Inline SVG        — auto-generated placeholder if no URL is set
#

install_distro_branding() {
    ui_info "  Installing KDE distro branding (logo + About This System)..."


    local icon_dir="$ORBIT_MOUNT/usr/share/icons/hicolor"
    mkdir -p "$icon_dir/scalable/apps"
    mkdir -p "$ORBIT_MOUNT/usr/share/pixmaps"

    local logo_installed="no"

    if [[ -n "$ORBIT_LOGO_URL" ]]; then
        ui_info "  Fetching OrbitOS logo from $ORBIT_LOGO_URL ..."
        if curl -fsSL "$ORBIT_LOGO_URL" \
                -o "$ORBIT_MOUNT/usr/share/pixmaps/orbitos.png" 2>/dev/null; then
            # Install PNG at multiple icon sizes so KDE finds it
            for size in 64 128 256; do
                mkdir -p "$icon_dir/${size}x${size}/apps"
                cp "$ORBIT_MOUNT/usr/share/pixmaps/orbitos.png" \
                   "$icon_dir/${size}x${size}/apps/orbitos.png"
            done
            logo_installed="yes"
            ui_ok "Logo downloaded and installed to icon theme"
        else
            ui_warn "Logo download failed — generating SVG placeholder"
        fi
    fi

    if [[ "$logo_installed" == "no" ]]; then
        cat > "$icon_dir/scalable/apps/orbitos.svg" << 'SVGEOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">
  <rect width="256" height="256" rx="32" fill="#0d1117"/>
  <ellipse cx="128" cy="128" rx="88" ry="88"
           fill="none" stroke="#17d4e8" stroke-width="8" stroke-dasharray="20 10"/>
  <circle cx="128" cy="128" r="36" fill="#17d4e8"/>
  <text x="128" y="228" font-family="sans-serif" font-size="28" font-weight="bold"
        fill="#ffffff" text-anchor="middle" letter-spacing="4">ORBIT</text>
</svg>
SVGEOF
        
        cp "$icon_dir/scalable/apps/orbitos.svg" \
           "$ORBIT_MOUNT/usr/share/pixmaps/orbitos.svg"
        ui_ok "SVG placeholder logo installed (replace $icon_dir/scalable/apps/orbitos.svg with your real logo)"
    fi

    # Rebuild icon cache so KDE picks it up
    arch-chroot "$ORBIT_MOUNT" gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor 2>/dev/null || true

    
    cat > "$ORBIT_MOUNT/etc/os-release" << EOF
NAME="OrbitOS"
PRETTY_NAME="OrbitOS"
ID=arch
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="38;2;23;147;209"
HOME_URL="https://github.com/MurderFromMars"
LOGO=orbitos
EOF
    cp "$ORBIT_MOUNT/etc/os-release" "$ORBIT_MOUNT/usr/lib/os-release" 2>/dev/null || true

    cat > "$ORBIT_MOUNT/etc/lsb-release" << 'EOF'
DISTRIB_ID="OrbitOS"
DISTRIB_RELEASE="rolling"
DISTRIB_DESCRIPTION="OrbitOS"
EOF

    # ── Optional: kcm-about-distroinfo for KDE About panel ────────────────
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed kcm-about-distroinfo 2>/dev/null || true

    local logo_path="/usr/share/pixmaps/orbitos.png"
    [[ "$logo_installed" == "no" ]] && logo_path="/usr/share/icons/hicolor/scalable/apps/orbitos.svg"

    mkdir -p "$ORBIT_MOUNT/etc/xdg"
    cat > "$ORBIT_MOUNT/etc/xdg/kcm-about-distrorc" << EOF
[General]
LogoPath=$logo_path
Name=OrbitOS
Website=https://github.com/MurderFromMars
EOF

    ui_ok "KDE About This System: OrbitOS branding configured"
}

# ────────────────────────────────────────────────────────────────────────────────
# ORBITOS EXTRAS: CyberXero Toolkit + PS4 Plasma Theme
# ────────────────────────────────────────────────────────────────────────────────

install_orbit_extras() {
    ui_info "Installing OrbitOS extras: CyberXero Toolkit + PS4 Plasma Theme..."

    ui_info "  Installing build/runtime dependencies..."
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
        rust cargo pkgconf \
        gtk4 glib2 libadwaita vte4 \
        polkit \
        cmake extra-cmake-modules \
        kitty cava imagemagick \
        scx-scheds \
        || ui_warn "Some build dependencies failed — toolkit build may fail"

    ui_info "  Cloning and building CyberXero Toolkit (Rust — may take a few minutes)..."
    local toolkit_built="no"
    arch-chroot "$ORBIT_MOUNT" su -l "${CFG[username]}" -c "
        set -e
        cd \$HOME
        # If rustup is present (pulled in by a dep), ensure it has a toolchain
        command -v rustup &>/dev/null && rustup default stable 2>/dev/null || true
        git clone https://github.com/MurderFromMars/CyberXero-Toolkit CyberXero-Toolkit 2>&1 | tail -3
        cd CyberXero-Toolkit
        cargo build --release 2>&1 | grep -E '^(error|Compiling|Finished)' | tail -20
    " && toolkit_built="yes" \
      || ui_warn "Toolkit build failed — re-run ~/CyberXero-Toolkit/install.sh after reboot."

    if [[ "$toolkit_built" == "yes" ]]; then
        ui_info "  Installing toolkit binaries..."
        arch-chroot "$ORBIT_MOUNT" bash << TOOLINSTALL || ui_warn "Toolkit binary install had errors — may need manual setup after reboot"
set -e
SRC="/home/${CFG[username]}/CyberXero-Toolkit"

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
    for s in "\$SRC/extra-scripts/usr/local/bin/"*; do
        [[ -f "\$s" ]] && install -Dm755 "\$s" "/usr/local/bin/\$(basename "\$s")"
    done
fi

rm -rf "\$SRC/target"
TOOLINSTALL

        ui_ok "CyberXero Toolkit installed → /opt/xero-toolkit  (run: xero-toolkit)"
    fi

    # ── PS4 theme — first-boot autostart ─────────────────────────────────────
    ui_info "  Preparing PS4 Plasma Theme first-boot autostart..."

    local autostart="$ORBIT_MOUNT/home/${CFG[username]}/.config/autostart"
    mkdir -p "$autostart"

    cat > "$autostart/orbitos-ps4-theme.sh" << 'FIRSTBOOT'
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

# Re-launch inside a visible terminal if not already running in one
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
        echo ""
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

rm -f "$SELF_DESKTOP" "$SELF_SCRIPT"
ok "First-boot setup complete. Closing in 10 seconds."
sleep 10
FIRSTBOOT

    chmod +x "$autostart/orbitos-ps4-theme.sh"

    cat > "$autostart/orbitos-ps4-theme.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=OrbitOS PS4 Theme Setup
Comment=Applies the PS4 Plasma theme on first login (runs once, then removes itself)
Exec=bash /home/${CFG[username]}/.config/autostart/orbitos-ps4-theme.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=panel
X-KDE-StartupNotify=false
DESKTOP

    arch-chroot "$ORBIT_MOUNT" chown -R "${CFG[username]}:${CFG[username]}" \
        "/home/${CFG[username]}/.config/autostart" 2>/dev/null || true

    ui_ok "PS4 Theme autostart ready — will apply on first login"
}

# ────────────────────────────────────────────────────────────────────────────────
# MAIN INSTALLATION FLOW
# ────────────────────────────────────────────────────────────────────────────────

perform_installation() {
    ui_header
    gum style --foreground 212 --bold --margin "1 2" "🚀 Starting OrbitOS installation..."
    echo ""

    # ── Phase 1: Disk ────────────────────────────────────────────────────────
    ui_step "Partitioning disk..."     partition_disk
    [[ "${CFG[encrypt]}" == "yes" ]] && ui_step "Setting up encryption..." setup_encryption
    ui_step "Formatting partitions..." format_partitions
    ui_step "Mounting filesystems..."  mount_filesystems

    # ── Phase 2: Base system + repos ─────────────────────────────────────────
    ui_info "Installing base system (this may take a while)..."
    install_base_system
    ui_ok "Base system installed"

    ui_info "Configuring repositories (Chaotic-AUR + CachyOS)..."
    add_repos
    ui_ok "Repositories configured"

    if [[ "${CFG[cachyos_optimized]}" == "yes" ]]; then
        ui_info "Upgrading to CachyOS optimized packages..."
        arch-chroot "$ORBIT_MOUNT" pacman -Syu --noconfirm \
            || ui_warn "Optimization pass had errors — system should still be functional"
        ui_ok "Packages upgraded to CachyOS optimized builds"
    fi

    # ── Phase 3: User + AUR helper (needed before handheld kernel swap) ──────
    # create_user and install_aur_helper are moved early so that
    # install_handheld_kernel can build linux-bazzite-bin from the AUR
    # as the unprivileged user with paru/yay.
    ui_step "Creating user account..."  create_user
    install_aur_helper

    # ── Phase 4: Handheld kernel swap ────────────────────────────────────────
    # Must run before install_bootloader so grub-mkconfig picks up the bazzite
    # vmlinuz/initrd paths when it scans /boot.
    if [[ "${CFG[handheld]}" == "yes" ]]; then
        ui_info "Switching to Bazzite kernel for handheld mode..."
        install_handheld_kernel
        ui_ok "Handheld kernel configured"
    fi

    # ── Phase 5: System config + bootloader ──────────────────────────────────
    ui_step "Configuring system..."    configure_system
    ui_step "Installing bootloader..." install_bootloader

    # ── Phase 6: Drivers + swap ──────────────────────────────────────────────
    ui_info "Auto-detecting hardware and installing drivers (chwd)..."
    install_drivers_chwd
    ui_ok "Hardware drivers configured"

    ui_step "Configuring swap..."      setup_swap_system

    # ── Phase 7: Desktop + gaming + branding + extras ────────────────────────
    ui_info "Installing minimal KDE Plasma..."
    install_kde_minimal
    ui_ok "KDE Plasma installed"

    ui_info "Installing CachyOS gaming packages..."
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
        cachyos-gaming-meta cachyos-gaming-applications \
        || {
            ui_warn "Gaming packages failed — retrying after database refresh..."
            arch-chroot "$ORBIT_MOUNT" pacman -Syy --noconfirm
            arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed \
                cachyos-gaming-meta cachyos-gaming-applications \
                || ui_warn "Gaming packages still failed — install manually after reboot: sudo pacman -S cachyos-gaming-meta cachyos-gaming-applications"
        }
    ui_ok "Gaming packages installed"

    ui_info "Applying OrbitOS distro branding..."
    install_distro_branding
    ui_ok "Distro branding applied"

    ui_info "Installing OrbitOS extras (CyberXero Toolkit + PS4 Theme)..."
    install_orbit_extras
    ui_ok "OrbitOS extras installed"

    local handheld_note=""
    [[ "${CFG[handheld]}" == "yes" ]] \
        && handheld_note="  • HHD Handheld Daemon → active on boot (run hhd-ui for settings)"

    ui_header
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
        "  • PS4 Plasma Theme  → applies automatically" \
        "$handheld_note"
    echo ""
}

# ────────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ────────────────────────────────────────────────────────────────────────────────

main() {
    require_root
    require_arch_iso
    detect_boot_mode
    require_network
    bootstrap_deps
    run_main_menu
}

main "$@"
