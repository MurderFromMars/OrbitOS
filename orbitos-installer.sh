#!/bin/bash
#
#  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
#  ██ OrbitOS Arch Installer                                     ██
#  ██ Arch Linux + KDE Plasma + CachyOS + PS4 Theme              ██
#  ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
#
#  Self-contained single-file installer.
#

set -Eeuo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# GLOBALS
# ══════════════════════════════════════════════════════════════════════════════

readonly ORBIT_VERSION="1.0"
readonly ORBIT_NAME="OrbitOS"
readonly ORBIT_MOUNT="/mnt"

ORBIT_LOGO_URL="https://raw.githubusercontent.com/MurderFromMars/OrbitOS/main/ps4.png"

# ── Neon blue terminal palette ───────────────────────────────────────────────
_nb=$'\033[1;34m'      # neon blue (bold blue)
_nc=$'\033[1;36m'      # neon cyan
_nw=$'\033[1;37m'      # bright white
_ng=$'\033[1;32m'      # green (success)
_ny=$'\033[1;33m'      # yellow (warning)
_nr=$'\033[1;31m'      # red (error)
_nd=$'\033[0;90m'      # dim gray
_n0=$'\033[0m'         # reset

# ── gum color constants (256-color) ──────────────────────────────────────────
readonly GUM_PRIMARY=33       # royal blue
readonly GUM_ACCENT=51        # electric cyan
readonly GUM_BRIGHT=39        # dodger blue
readonly GUM_DIM=105          # muted slate blue
readonly GUM_SUCCESS=48       # spring green
readonly GUM_WARN=214         # amber
readonly GUM_ERR=196          # red
readonly GUM_MUTED=245        # gray

# ── State ────────────────────────────────────────────────────────────────────
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

ADDON_PKGS=""

# ══════════════════════════════════════════════════════════════════════════════
# RENDER ENGINE
# ══════════════════════════════════════════════════════════════════════════════

_has_gum() { command -v gum &>/dev/null; }

# ── Brand bar ────────────────────────────────────────────────────────────────
ui_header() {
    clear
    if _has_gum; then
        printf "\n"
        gum style \
            --foreground $GUM_ACCENT --border-foreground $GUM_PRIMARY \
            --border rounded --align center --width 64 \
            --margin "0 4" --padding "1 3" \
            "$(gum style --foreground $GUM_ACCENT --bold '░▒▓  O R B I T O S  ▓▒░')" \
            "" \
            "$(gum style --foreground $GUM_DIM "v${ORBIT_VERSION}  //  Arch + Plasma + CachyOS")"
        printf "\n"
    else
        printf "\n${_nb}  ░▒▓  O R B I T O S  v%s  ▓▒░${_n0}\n\n" "$ORBIT_VERSION"
    fi
}

# ── Section divider ──────────────────────────────────────────────────────────
ui_section() {
    if _has_gum; then
        gum style --foreground $GUM_BRIGHT --bold --margin "1 4" \
            "▓▒░ $1"
    else
        printf "\n${_nc}▓▒░ %s${_n0}\n" "$1"
    fi
}

# ── Status lines ─────────────────────────────────────────────────────────────
ui_info() {
    if _has_gum; then
        gum style --foreground $GUM_DIM --margin "0 6" ":: $1"
    else
        printf "  ${_nd}::${_n0} %s\n" "$1"
    fi
}

ui_ok() {
    if _has_gum; then
        gum style --foreground $GUM_SUCCESS --margin "0 6" ">> $1"
    else
        printf "  ${_ng}>>${_n0} %s\n" "$1"
    fi
}

ui_warn() {
    if _has_gum; then
        gum style --foreground $GUM_WARN --margin "0 6" "!! $1"
    else
        printf "  ${_ny}!!${_n0} %s\n" "$1"
    fi
}

ui_err() {
    if _has_gum; then
        gum style --foreground $GUM_ERR --margin "0 6" "XX $1"
    else
        printf "  ${_nr}XX${_n0} %s\n" "$1"
    fi
}

# ── Confirm prompt ───────────────────────────────────────────────────────────
ui_confirm() {
    if _has_gum; then
        gum confirm \
            --prompt.foreground $GUM_ACCENT \
            --selected.background $GUM_PRIMARY \
            --unselected.foreground $GUM_MUTED \
            --affirmative "Yes" --negative "No" "$1"
    else
        local ans
        read -rp "  ${_nc}$1 [y/N]${_n0} " ans
        [[ "${ans,,}" == "y" ]]
    fi
}

# ── Run labelled step ────────────────────────────────────────────────────────
ui_step() {
    local label="$1"; shift
    ui_info "$label"
    "$@"
    ui_ok "${label%...}"
}

# ── Styled gum choose wrapper ───────────────────────────────────────────────
_orbit_choose() {
    local header="$1"; shift
    local height="${1:-10}"; shift
    printf '%s\n' "$@" \
        | gum choose \
            --header "$header" \
            --header.foreground $GUM_ACCENT \
            --cursor.foreground $GUM_BRIGHT \
            --selected.foreground $GUM_SUCCESS \
            --height "$height"
}

# ── Styled gum filter wrapper ───────────────────────────────────────────────
_orbit_filter() {
    local placeholder="$1"; shift
    local height="${1:-12}"; shift
    if [[ $# -gt 0 ]]; then
        printf '%s\n' "$@"
    else
        cat
    fi \
        | gum filter \
            --placeholder "$placeholder" \
            --prompt.foreground $GUM_ACCENT \
            --indicator.foreground $GUM_BRIGHT \
            --match.foreground $GUM_SUCCESS \
            --height "$height"
}

# ── Styled gum input wrapper ────────────────────────────────────────────────
_orbit_input() {
    local placeholder="$1"
    local width="${2:-40}"
    local header="${3:-}"
    local args=(
        --placeholder "$placeholder"
        --width "$width"
        --prompt.foreground $GUM_ACCENT
        --cursor.foreground $GUM_BRIGHT
    )
    [[ -n "$header" ]] && args+=(--header "$header" --header.foreground $GUM_ACCENT)
    gum input "${args[@]}"
}

# ── Styled gum input --password wrapper ──────────────────────────────────────
_orbit_password() {
    local placeholder="$1"
    local width="${2:-50}"
    gum input --password \
        --placeholder "$placeholder" \
        --width "$width" \
        --prompt.foreground $GUM_ACCENT \
        --cursor.foreground $GUM_BRIGHT
}

# ── Description block ────────────────────────────────────────────────────────
_orbit_desc() {
    gum style --foreground $GUM_MUTED --margin "0 6" "$@"
}

# ══════════════════════════════════════════════════════════════════════════════
# ERROR HANDLING
# ══════════════════════════════════════════════════════════════════════════════

_trap_err() {
    local code=$? line=${1:-?} command=${2:-?}
    if _has_gum; then
        gum style --foreground $GUM_ERR --bold --margin "1 4" \
            "XX Installer crashed (exit $code) at line $line" \
            "   Command: $command"
        echo ""
        gum input --placeholder "Press Enter to exit..."
    else
        printf "\n${_nr}Crash at line %s (exit %s): %s${_n0}\n" \
            "$line" "$code" "$command"
    fi
    exit "$code"
}

trap '_trap_err "$LINENO" "$BASH_COMMAND"' ERR

# ══════════════════════════════════════════════════════════════════════════════
# PREFLIGHT
# ══════════════════════════════════════════════════════════════════════════════

require_root() {
    [[ ${EUID:-1} -eq 0 ]] && return
    printf "${_nr}Error: must be run as root.${_n0}\n"
    printf "Run: sudo bash %s\n" "$0"
    exit 1
}

detect_boot_mode() {
    [[ -d /sys/firmware/efi/efivars ]] \
        && CFG[uefi]="yes" \
        || CFG[uefi]="no"
}

_net_checked="no"
require_network() {
    [[ "$_net_checked" == "yes" ]] && return 0
    if ping -c 1 -W 3 archlinux.org &>/dev/null; then
        _net_checked="yes"
        return 0
    fi
    printf "${_nr}Error: no internet connection detected.${_n0}\n"
    exit 1
}

require_arch_iso() {
    [[ -f /etc/arch-release ]] && return
    printf "${_nr}Error: must be run from the Arch Linux live ISO.${_n0}\n"
    exit 1
}

bootstrap_deps() {
    local missing=()
    command -v gum         &>/dev/null || missing+=(gum)
    command -v parted      &>/dev/null || missing+=(parted)
    command -v arch-chroot &>/dev/null || missing+=(arch-install-scripts)
    command -v sgdisk      &>/dev/null || missing+=(gptfdisk)
    command -v mkfs.btrfs  &>/dev/null || missing+=(btrfs-progs)
    command -v mkfs.fat    &>/dev/null || missing+=(dosfstools)
    command -v mkfs.ext4   &>/dev/null || missing+=(e2fsprogs)
    command -v cryptsetup  &>/dev/null || missing+=(cryptsetup)

    if [[ ${#missing[@]} -gt 0 ]]; then
        printf "${_nc}:: Fetching dependencies: %s${_n0}\n" "${missing[*]}"
        rm -f /var/lib/pacman/db.lck
        pacman -Sy --noconfirm --noprogressbar "${missing[@]}" 2>&1
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# PACMAN HELPERS
# ══════════════════════════════════════════════════════════════════════════════

pacman_set_parallel() {
    local conf="$1" n="${CFG[parallel_downloads]}"
    if grep -q '^#*ParallelDownloads' "$conf"; then
        sed -i "s/^#*ParallelDownloads.*/ParallelDownloads = $n/" "$conf"
    else
        sed -i '/^\[options\]/a ParallelDownloads = '"$n" "$conf"
    fi
}

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

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION PANELS
# ══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────── 1. IDENTITY ─────────────────────────────────────

panel_identity() {
    ui_header
    ui_section "Identity"
    echo ""

    # Hostname
    _orbit_desc "Machine name (lowercase, a-z / 0-9 / dash)"
    echo ""
    local h=""
    h=$(_orbit_input "orbitos" 40 "Hostname") || true
    if [[ "$h" =~ ^[a-z][a-z0-9-]*$ && ${#h} -le 63 ]]; then
        CFG[hostname]="$h"
    else
        ui_warn "Invalid hostname, keeping: ${CFG[hostname]}"
    fi
    ui_ok "Hostname: ${CFG[hostname]}"

    # Username
    echo ""
    _orbit_desc "Login username (lowercase only)"
    echo ""
    local u=""
    u=$(_orbit_input "username" 40 "Username") || true
    if [[ ! "$u" =~ ^[a-z_][a-z0-9_-]*$ || ${#u} -gt 32 || -z "$u" ]]; then
        ui_warn "Invalid username, falling back to 'user'"
        u="user"
    fi
    CFG[username]="$u"
    ui_ok "Username: ${CFG[username]}"

    # User password
    echo ""
    local p1="" p2=""
    p1=$(_orbit_password "Password for $u") || true
    p2=$(_orbit_password "Confirm password") || true
    if [[ "$p1" == "$p2" && -n "$p1" ]]; then
        CFG[user_password]="$p1"
        ui_ok "User password set"
    else
        ui_err "Passwords don't match, try again."
        sleep 1; panel_identity; return
    fi

    # Root password
    echo ""
    ui_section "Root Password"
    echo ""
    if ui_confirm "Use the same password for root?"; then
        CFG[root_password]="${CFG[user_password]}"
        ui_ok "Root: same as user"
    else
        local r1="" r2=""
        r1=$(_orbit_password "Root password") || true
        r2=$(_orbit_password "Confirm root password") || true
        if [[ "$r1" == "$r2" && -n "$r1" ]]; then
            CFG[root_password]="$r1"
            ui_ok "Root password set"
        else
            ui_warn "Mismatch, using user password for root."
            CFG[root_password]="${CFG[user_password]}"
        fi
    fi
    sleep 0.4
}

# ─────────────────────────── 2. STORAGE ──────────────────────────────────────

panel_storage() {
    ui_header
    ui_section "Storage"
    echo ""

    local mode=""
    mode=$(_orbit_choose "Partitioning mode:" 4 \
        "Auto    // Wipe entire disk" \
        "Manual  // Choose existing partitions") || true

    if [[ "$mode" == "Manual"* ]]; then
        CFG[partition_mode]="manual"
        _storage_manual
    else
        CFG[partition_mode]="auto"
        _storage_auto
    fi
}

_storage_manual() {
    ui_header
    ui_section "Manual Partitioning"
    echo ""
    gum style --foreground $GUM_WARN --bold --margin "0 6" \
        "Assigned partitions will be formatted. Others untouched."
    echo ""
    gum style --foreground $GUM_MUTED --margin "0 6" \
        "$(lsblk -o NAME,SIZE,FSTYPE,LABEL,TYPE,MOUNTPOINT 2>/dev/null)"
    echo ""

    if ui_confirm "Launch cfdisk first?"; then
        local raw_disks=()
        while IFS= read -r ln; do [[ -n "$ln" ]] && raw_disks+=("$ln"); done \
            < <(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null \
                | { grep -E '^/dev/(sd|nvme|vd|mmcblk)' || true; } \
                | sed 's/  */ /g')
        if [[ ${#raw_disks[@]} -gt 0 ]]; then
            local d=""
            d=$(_orbit_choose "Disk to edit:" 10 "${raw_disks[@]}") || true
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
        && ui_info "Select EFI System Partition" \
        || ui_info "Select boot partition (or skip)"
    echo ""

    local boot_list=("-- Skip --")
    for p in "${parts[@]}"; do boot_list+=("$p"); done

    local boot_pick=""
    boot_pick=$(_orbit_choose "Boot/EFI partition:" 14 "${boot_list[@]}") || true

    if [[ "$boot_pick" == "-- Skip --" ]]; then
        CFG[boot_part]=""; CFG[reuse_efi]="no"
    else
        CFG[boot_part]=$(awk '{print $1}' <<< "$boot_pick")
        ui_ok "Boot/EFI: ${CFG[boot_part]}"
        if [[ "${CFG[uefi]}" == "yes" ]]; then
            echo ""
            local efi_action=""
            efi_action=$(_orbit_choose "EFI partition action:" 4 \
                "Format  // Wipe and format as FAT32" \
                "Reuse   // Mount without formatting") || true
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
    root_pick=$(_orbit_choose "Root (/) partition:" 14 "${parts[@]}") || true
    [[ -z "$root_pick" ]] && { ui_err "No root partition selected."; return; }
    CFG[root_part]=$(awk '{print $1}' <<< "$root_pick")
    ui_ok "Root: ${CFG[root_part]}"

    local pk
    pk=$(lsblk -no PKNAME "${CFG[root_part]}" 2>/dev/null | head -1)
    CFG[disk]="${pk:+/dev/$pk}"
    [[ -z "${CFG[disk]}" ]] && CFG[disk]="${CFG[root_part]}"

    _pick_fs
    _pick_luks

    sleep 0.4
}

_storage_auto() {
    ui_header
    ui_section "Disk Selection"
    echo ""
    gum style --foreground $GUM_ERR --bold --margin "0 6" \
        "WARNING: the selected disk will be completely erased."
    echo ""

    local raw_disks=()
    while IFS= read -r ln; do [[ -n "$ln" ]] && raw_disks+=("$ln"); done \
        < <(lsblk -dpno NAME,SIZE,MODEL 2>/dev/null \
            | { grep -E '^/dev/(sd|nvme|vd|mmcblk)' || true; } \
            | sed 's/  */ /g')

    [[ ${#raw_disks[@]} -eq 0 ]] && { ui_err "No suitable disks found."; exit 1; }

    local d=""
    d=$(_orbit_choose "Target disk:" 10 "${raw_disks[@]}") || true
    if [[ -n "$d" ]]; then
        CFG[disk]=$(awk '{print $1}' <<< "$d")
        ui_ok "Disk: ${CFG[disk]}"
        echo ""
        gum style --foreground $GUM_MUTED --margin "0 6" \
            "$(lsblk "${CFG[disk]}" 2>/dev/null)"
    fi

    _pick_fs

    # Encryption
    echo ""
    ui_section "Disk Encryption"
    echo ""
    if ui_confirm "Enable full disk encryption (LUKS2)?"; then
        CFG[encrypt]="yes"
        local p1="" p2=""
        p1=$(_orbit_password "Encryption password") || true
        p2=$(_orbit_password "Confirm password") || true
        if [[ "$p1" == "$p2" && -n "$p1" ]]; then
            CFG[encrypt_password]="$p1"
            echo ""
            local scope=""
            scope=$(_orbit_choose "Encryption scope:" 4 \
                "root      // Encrypt root only (faster boot)" \
                "root+boot // Encrypt root and boot (more secure)") || true
            [[ "$scope" == "root+boot"* ]] \
                && CFG[encrypt_boot]="yes" \
                || CFG[encrypt_boot]="no"
            ui_ok "Encryption enabled"
        else
            ui_err "Passwords don't match, encryption disabled."
            CFG[encrypt]="no"; CFG[encrypt_boot]="no"; CFG[encrypt_password]=""
        fi
    else
        CFG[encrypt]="no"; CFG[encrypt_boot]="no"; CFG[encrypt_password]=""
    fi

    # Swap (bundled into storage panel)
    echo ""
    ui_section "Swap"
    echo ""
    local sw=""
    sw=$(_orbit_choose "Swap type:" 5 \
        "zram     // Compressed RAM (recommended)" \
        "file     // Traditional swap file" \
        "none     // No swap") || true
    if [[ -n "$sw" ]]; then
        CFG[swap]=$(awk '{print $1}' <<< "$sw")
        ui_ok "Swap: ${CFG[swap]}"
        if [[ "${CFG[swap]}" == "zram" ]]; then
            echo ""
            local algo=""
            algo=$(_orbit_choose "Compression algorithm:" 5 \
                "zstd     // Best ratio (recommended)" \
                "lz4      // Fastest" \
                "lzo      // Balanced") || true
            [[ -n "$algo" ]] \
                && CFG[swap_algo]=$(awk '{print $1}' <<< "$algo") \
                && ui_ok "Algorithm: ${CFG[swap_algo]}"
        fi
    fi

    sleep 0.4
}

_pick_fs() {
    echo ""
    ui_section "Filesystem"
    echo ""
    local fs=""
    fs=$(_orbit_choose "Filesystem:" 5 \
        "btrfs    // CoW with snapshots (recommended)" \
        "ext4     // Traditional, reliable" \
        "xfs      // High performance") || true
    if [[ -n "$fs" ]]; then
        CFG[filesystem]=$(awk '{print $1}' <<< "$fs")
        ui_ok "Filesystem: ${CFG[filesystem]}"
    fi
}

_pick_luks() {
    echo ""
    if ui_confirm "Enable LUKS2 encryption on root?"; then
        CFG[encrypt]="yes"; CFG[encrypt_boot]="no"
        local p1="" p2=""
        p1=$(_orbit_password "Encryption password") || true
        p2=$(_orbit_password "Confirm password") || true
        if [[ "$p1" == "$p2" && -n "$p1" ]]; then
            CFG[encrypt_password]="$p1"; ui_ok "Encryption enabled"
        else
            ui_err "Passwords don't match, encryption disabled."
            CFG[encrypt]="no"; CFG[encrypt_password]=""
        fi
    else
        CFG[encrypt]="no"; CFG[encrypt_boot]="no"; CFG[encrypt_password]=""
    fi
}

# ─────────────────────────── 3. REGION ───────────────────────────────────────

panel_region() {
    ui_header
    ui_section "Region"
    echo ""

    # Locale
    _orbit_desc "System locale for language and number formatting"
    echo ""

    local locales=(
        "en_US.UTF-8" "en_GB.UTF-8" "de_DE.UTF-8" "fr_FR.UTF-8"
        "es_ES.UTF-8" "it_IT.UTF-8" "pt_BR.UTF-8" "pt_PT.UTF-8"
        "ru_RU.UTF-8" "ja_JP.UTF-8" "ko_KR.UTF-8" "zh_CN.UTF-8"
        "pl_PL.UTF-8" "nl_NL.UTF-8" "tr_TR.UTF-8" "sv_SE.UTF-8"
        "da_DK.UTF-8" "fi_FI.UTF-8" "nb_NO.UTF-8" "cs_CZ.UTF-8"
    )

    local picked=""
    picked=$(_orbit_filter "Search locale..." 12 "${locales[@]}") || true
    [[ -n "$picked" ]] && CFG[locale]="$picked" && ui_ok "Locale: $picked"

    # Keyboard
    echo ""
    _orbit_desc "Console keyboard layout"
    echo ""

    local layouts=(
        "us" "uk" "de" "fr" "es" "it" "pt-latin9" "br-abnt2"
        "ru" "pl" "cz" "hu" "se" "no" "dk" "fi" "nl" "jp106"
        "dvorak" "colemak"
    )

    local kb=""
    kb=$(_orbit_choose "Keyboard:" 12 "${layouts[@]}") || true
    if [[ -n "$kb" ]]; then
        CFG[keyboard]="$kb"
        loadkeys "$kb" 2>/dev/null || true
        ui_ok "Keyboard: $kb"
    fi

    # Timezone
    echo ""
    _orbit_desc "Select timezone region, then city"
    echo ""

    local regions=""
    regions=$(find /usr/share/zoneinfo -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
              | grep -vE '^(\+|posix|right|zoneinfo)$' | sort) || true

    local region=""
    region=$(echo "$regions" | _orbit_filter "Search region..." 12) || true

    if [[ -n "$region" ]]; then
        local cities=""
        cities=$(find "/usr/share/zoneinfo/$region" -type f -printf '%f\n' 2>/dev/null | sort) || true
        if [[ -n "$cities" ]]; then
            echo ""
            local city=""
            city=$(echo "$cities" | _orbit_filter "Search city..." 12) || true
            [[ -n "$city" ]] \
                && CFG[timezone]="$region/$city" \
                || CFG[timezone]="$region"
        else
            CFG[timezone]="$region"
        fi
        ui_ok "Timezone: ${CFG[timezone]}"
    fi
    sleep 0.4
}

# ─────────────────────────── 4. PERFORMANCE ──────────────────────────────────

panel_performance() {
    ui_header
    ui_section "Performance"
    echo ""

    # CachyOS toggle
    _orbit_desc \
        "CachyOS rebuilds core packages (glibc, mesa, etc.)" \
        "with x86-64-v3/v4 instructions for modern CPUs." \
        "" \
        "Safe on any CPU from ~2013 onwards (Haswell+)." \
        "CPU capability is auto-detected."
    echo ""
    if ui_confirm "Enable CachyOS optimized packages?"; then
        CFG[cachyos_optimized]="yes"
        ui_ok "CachyOS optimized: enabled"
    else
        CFG[cachyos_optimized]="no"
        ui_ok "Using vanilla Arch packages"
    fi

    # Parallel downloads
    echo ""
    _orbit_desc "Simultaneous package downloads during install"
    echo ""
    local pd=""
    pd=$(_orbit_choose "Parallel downloads:" 6 \
        "3      // Conservative" \
        "5      // Default" \
        "10     // Fast" \
        "15     // Maximum") || true
    [[ -n "$pd" ]] \
        && CFG[parallel_downloads]=$(awk '{print $1}' <<< "$pd") \
        && ui_ok "Parallel downloads: ${CFG[parallel_downloads]}"
    sleep 0.4
}

# ─────────────────────────── 5. DESKTOP ──────────────────────────────────────

panel_desktop() {
    ui_header
    ui_section "Desktop"
    echo ""

    # Login manager
    _orbit_desc "Display manager for the graphical login screen"
    echo ""
    local lm=""
    lm=$(_orbit_choose "Login manager:" 4 \
        "sddm            // Stable, widely used" \
        "plasma-login    // New KDE native manager") || true
    [[ -n "$lm" ]] \
        && CFG[login_manager]=$(awk '{print $1}' <<< "$lm") \
        && ui_ok "Login manager: ${CFG[login_manager]}"

    # AUR helper
    echo ""
    _orbit_desc "AUR helper for community packages"
    echo ""
    local ah=""
    ah=$(_orbit_choose "AUR helper:" 4 \
        "paru   // Rust, feature rich" \
        "yay    // Go, widely used") || true
    [[ -n "$ah" ]] \
        && CFG[aur_helper]=$(awk '{print $1}' <<< "$ah") \
        && ui_ok "AUR helper: ${CFG[aur_helper]}"

    # Extra packages
    echo ""
    ui_section "Optional Packages"
    echo ""
    _orbit_desc "Space to toggle, Enter to confirm"
    echo ""

    local catalogue=(
        "firefox            Web browser"
        "brave-bin          Brave browser"
        "librewolf          Privacy focused browser"
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
        "obsidian           Note taking"
    )

    local labels=()
    declare -A label_to_pkg
    for entry in "${catalogue[@]}"; do
        local pkg lbl
        pkg=$(awk '{print $1}' <<< "$entry")
        lbl=$(awk '{$1=""; print substr($0,2)}' <<< "$entry")
        local display="$pkg  // $lbl"
        labels+=("$display")
        label_to_pkg["$display"]="$pkg"
    done

    local selected=""
    selected=$(printf '%s\n' "${labels[@]}" \
        | gum choose --no-limit --height 20 \
            --header "Extra packages (space to select):" \
            --header.foreground $GUM_ACCENT \
            --cursor.foreground $GUM_BRIGHT \
            --selected.foreground $GUM_SUCCESS) || true

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
    sleep 0.4
}

# ─────────────────────────── 6. HARDWARE ─────────────────────────────────────

panel_hardware() {
    ui_header
    ui_section "Handheld Mode"
    echo ""
    _orbit_desc \
        "Replaces linux-zen with linux-bazzite-bin and installs" \
        "HHD (Handheld Daemon) for gamepad, gyro, and TDP control." \
        "" \
        "Supported: Steam Deck, ROG Ally, Legion Go, GPD Win," \
        "OneXPlayer, AYA NEO, MSI Claw, and more." \
        "" \
        "inputplumber and steamos-manager will be masked;" \
        "hhd will be enabled instead."
    echo ""
    if ui_confirm "Enable handheld mode?"; then
        CFG[handheld]="yes"
        ui_ok "Handheld mode: enabled (linux-bazzite-bin + HHD)"
    else
        CFG[handheld]="no"
        ui_ok "Handheld mode: disabled (linux-zen)"
    fi
    sleep 0.4
}

# ══════════════════════════════════════════════════════════════════════════════
# REVIEW
# ══════════════════════════════════════════════════════════════════════════════

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
        gum style --foreground $GUM_ERR --bold --margin "1 4" "XX Configuration incomplete"
        echo ""
        for p in "${problems[@]}"; do ui_err "$p"; done
        echo ""
        gum input --placeholder "Press Enter to return..."
        return 1
    fi
    return 0
}

show_summary() {
    ui_header
    ui_section "Review Configuration"
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

    gum style --border rounded --border-foreground $GUM_PRIMARY \
        --foreground $GUM_ACCENT --padding "1 3" --margin "0 4" \
        "IDENTITY" \
        "  Hostname     ${CFG[hostname]}" \
        "  Username     ${CFG[username]}" \
        "" \
        "STORAGE" \
        "  Disk         $disk_label" \
        "  Mode         ${CFG[partition_mode]}" \
        "  Filesystem   ${CFG[filesystem]}" \
        "  Encryption   $enc_label" \
        "  Swap         ${CFG[swap]}" \
        "" \
        "REGION" \
        "  Locale       ${CFG[locale]}" \
        "  Keyboard     ${CFG[keyboard]}" \
        "  Timezone     ${CFG[timezone]}" \
        "" \
        "SYSTEM" \
        "  Boot mode    $boot_label" \
        "  Graphics     Auto (chwd)" \
        "  Optimized    $cachyos_label" \
        "  AUR helper   ${CFG[aur_helper]}" \
        "  Login mgr    ${CFG[login_manager]}" \
        "  Downloads    ${CFG[parallel_downloads]} parallel" \
        "  Handheld     $handheld_label" \
        "  Extra pkgs   ${ADDON_PKGS:-none}"
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ══════════════════════════════════════════════════════════════════════════════

_fmt_val() {
    # Compact display value for the menu grid
    local raw="$1" max="${2:-20}"
    [[ ${#raw} -gt $max ]] && raw="${raw:0:$((max-2))}.."
    echo "$raw"
}

run_main_menu() {
    while true; do
        ui_header

        local boot_mode="BIOS"
        [[ "${CFG[uefi]}" == "yes" ]] && boot_mode="UEFI"
        gum style --foreground $GUM_DIM --margin "0 6" "Boot: $boot_mode"
        echo ""

        # Build status strings
        local id_status="${CFG[username]:-unconfigured}"
        [[ -n "${CFG[username]}" ]] && id_status="${CFG[username]}@${CFG[hostname]}"

        local disk_status="${CFG[disk]:-unconfigured}"
        [[ "${CFG[partition_mode]}" == "manual" && -n "${CFG[root_part]}" ]] \
            && disk_status="manual: ${CFG[root_part]}"

        local perf_status="vanilla"
        [[ "${CFG[cachyos_optimized]}" == "yes" ]] && perf_status="CachyOS"

        local hw_status="desktop"
        [[ "${CFG[handheld]}" == "yes" ]] && hw_status="handheld"

        local entries=(
            ""
            "1.  Identity       $(_fmt_val "$id_status")"
            "2.  Storage        $(_fmt_val "$disk_status") [${CFG[filesystem]}]"
            "3.  Region         $(_fmt_val "${CFG[locale]}") / ${CFG[keyboard]}"
            "4.  Performance    $(_fmt_val "$perf_status") / ${CFG[parallel_downloads]} DLs"
            "5.  Desktop        ${CFG[login_manager]} / ${CFG[aur_helper]}"
            "6.  Hardware       $hw_status"
            "==========================================="
            "7.  >> Begin Installation"
            "0.  << Exit"
        )

        local choice=""
        choice=$(printf '%s\n' "${entries[@]}" \
            | gum choose --height 14 \
                --header "Configure:" \
                --header.foreground $GUM_ACCENT \
                --cursor.foreground $GUM_BRIGHT \
                --selected.foreground $GUM_SUCCESS) || true

        case "$choice" in
            "1."*) panel_identity ;;
            "2."*) panel_storage ;;
            "3."*) panel_region ;;
            "4."*) panel_performance ;;
            "5."*) panel_desktop ;;
            "6."*) panel_hardware ;;
            "7."*)
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

_resolve_x11_keyboard() {
    local keymap="$1"
    _x11_variant=""
    case "$keymap" in
        uk)         _x11_layout="gb" ;;
        pt-latin9)  _x11_layout="pt" ;;
        br-abnt2)   _x11_layout="br" ;;
        jp106)      _x11_layout="jp" ;;
        dvorak)     _x11_layout="us"; _x11_variant="dvorak" ;;
        colemak)    _x11_layout="us"; _x11_variant="colemak" ;;
        *)          _x11_layout="$keymap" ;;
    esac
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

    _resolve_x11_keyboard "${CFG[keyboard]}"

    mkdir -p "$ORBIT_MOUNT/etc/X11/xorg.conf.d"
    cat > "$ORBIT_MOUNT/etc/X11/xorg.conf.d/00-keyboard.conf" << EOF
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout"  "$_x11_layout"
    Option "XkbModel"   "pc104"
    Option "XkbVariant" "$_x11_variant"
EndSection
EOF

    local kde_dir="$ORBIT_MOUNT/home/${CFG[username]}/.config"
    mkdir -p "$kde_dir"
    cat > "$kde_dir/kxkbrc" << EOF
[Layout]
DisplayNames=
LayoutList=$_x11_layout
LayoutLoopCount=-1
Model=pc104
Options=
ResetOldOptions=false
Use=true
VariantList=$_x11_variant
EOF
    arch-chroot "$ORBIT_MOUNT" chown -R "${CFG[username]}:${CFG[username]}" \
        "/home/${CFG[username]}/.config" 2>/dev/null || true

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

    local stray=""
    stray=$(arch-chroot "$ORBIT_MOUNT" pacman -Qqs '^linux-cachyos' 2>/dev/null || true)
    if [[ -n "$stray" ]]; then
        ui_warn "Unexpected CachyOS kernels found — removing to avoid conflicts: $stray"
        arch-chroot "$ORBIT_MOUNT" pacman -Rdd --noconfirm $stray 2>/dev/null || true
    fi
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed linux-zen linux-zen-headers
    if [[ "${CFG[handheld]}" == "yes" ]]; then
        ui_ok "Kernel: linux-zen (bazzite replaces it on first login)"
    else
        ui_ok "Kernel: linux-zen + linux-zen-headers"
    fi

    ui_info "  Installing chwd hardware detector..."
    arch-chroot "$ORBIT_MOUNT" pacman -S --noconfirm --needed chwd \
        || { ui_warn "chwd install failed — install drivers manually after reboot."; return 0; }
    ui_ok "chwd installed"

    ui_info "  Running hardware auto-detection..."
    arch-chroot "$ORBIT_MOUNT" chwd -a -f \
        || { ui_warn "chwd auto-detection failed — install drivers manually after reboot."; return 0; }
    ui_ok "Hardware drivers installed via chwd"

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

prepare_handheld_marker() {
    [[ "${CFG[handheld]}" == "yes" ]] || return 0

    local marker="$ORBIT_MOUNT/home/${CFG[username]}/.config/orbitos-handheld"
    mkdir -p "$(dirname "$marker")"
    echo "pending" > "$marker"
    arch-chroot "$ORBIT_MOUNT" chown "${CFG[username]}:${CFG[username]}" \
        "/home/${CFG[username]}/.config/orbitos-handheld" 2>/dev/null || true
    ui_ok "Handheld kernel swap deferred to first Plasma login"
}


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
        topgrade \
        cachyos-settings \
        grub-hook

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

SELF_SCRIPT="$HOME/.config/autostart/orbitos-ps4-theme.sh"
SELF_DESKTOP="$HOME/.config/autostart/orbitos-ps4-theme.desktop"
REPO_DIR="$HOME/Playstation-4-Plasma"
HANDHELD_MARKER="$HOME/.config/orbitos-handheld"

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
printf   "\033[1;35m║   OrbitOS — First-Boot Setup                         ║\033[0m\n"
printf   "\033[1;35m╚══════════════════════════════════════════════════════╝\033[0m\n\n"

# ── PS4 Plasma Theme ────────────────────────────────────────────────────────
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

# ── Return to Gaming Mode desktop shortcut (handheld only) ────────────────────
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
    # Mark as trusted so Plasma doesn't show the "untrusted" warning
    gio set "$HOME/Desktop/Return to Gaming Mode.desktop" \
        metadata::trusted true 2>/dev/null || true
    ok "'Return to Gaming Mode' shortcut placed on desktop"
fi

# ── Handheld Kernel Swap (linux-zen → linux-bazzite-bin) ──────────────────────

if [[ -f "$HANDHELD_MARKER" ]]; then
    echo ""
    printf "\033[1;35m── Handheld Mode: Bazzite Kernel ──\033[0m\n\n"

    # Detect whichever AUR helper is installed
    AUR_HELPER=""
    if   command -v paru &>/dev/null; then AUR_HELPER="paru"
    elif command -v yay  &>/dev/null; then AUR_HELPER="yay"
    fi

    if [[ -z "$AUR_HELPER" ]]; then
        err "No AUR helper found (paru/yay) — cannot install linux-bazzite-bin."
        warn "Install manually: paru -S linux-bazzite-bin"
        warn "Then remove linux-zen: sudo pacman -Rdd linux-zen linux-zen-headers"
    else
        log "Building linux-bazzite-bin via $AUR_HELPER (this may take a while)..."
        if $AUR_HELPER -S --noconfirm --needed linux-bazzite-bin; then
            ok "linux-bazzite-bin installed"

            log "Removing linux-zen..."
            sudo pacman -Rdd --noconfirm linux-zen linux-zen-headers 2>/dev/null \
                && ok "linux-zen removed" \
                || warn "linux-zen removal had errors — remove manually: sudo pacman -Rdd linux-zen linux-zen-headers"

            rm -f "$HANDHELD_MARKER"
            ok "Handheld kernel swap complete!"
            echo ""
            warn "⚠️  A reboot is required to boot into the Bazzite kernel."
            warn "   Run: sudo reboot"
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
    gum style --foreground $GUM_ACCENT --bold --margin "1 4" "▓▒░ Starting OrbitOS installation..."
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

    # ── Phase 3: User + AUR helper ──────────────────────────────────────────
    ui_step "Creating user account..."  create_user
    install_aur_helper

    # ── Phase 4: Handheld marker ─────────────────────────────────────────────
    if [[ "${CFG[handheld]}" == "yes" ]]; then
        prepare_handheld_marker
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
        && handheld_note="  >> HHD Handheld Daemon active on boot (run hhd-ui for settings)
  >> Bazzite kernel builds on first Plasma login (reboot after)"

    ui_header
    gum style --foreground $GUM_SUCCESS --bold --border rounded --border-foreground $GUM_PRIMARY \
        --align center --width 68 --margin "1 4" --padding "1 2" \
        "▓▒░  OrbitOS Installation Complete  ░▒▓" \
        "" \
        "Remove installation media and reboot:" \
        "  sudo reboot" \
        "" \
        "On first login (log into Plasma desktop):" \
        "  >> Gaming (Steam, Lutris, Heroic) ready to go" \
        "  >> CyberXero Toolkit: run xero-toolkit" \
        "  >> PS4 Plasma Theme applies automatically" \
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
