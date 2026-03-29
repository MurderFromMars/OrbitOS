```
░▒▓  O R B I T O S  ▓▒░
Arch Linux // KDE Plasma // CachyOS // PS4 Theme
```

A minimal, gaming-ready Arch Linux installer with a PS4-inspired KDE Plasma desktop,
automatic hardware detection, and handheld device support.

[![Arch Linux](https://img.shields.io/badge/Arch-Linux-1793D1?style=flat&logo=archlinux&logoColor=white)](https://archlinux.org)
[![KDE Plasma](https://img.shields.io/badge/KDE-Plasma%206-1D99F3?style=flat&logo=kde&logoColor=white)](https://kde.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Quick Start

Boot into the Arch Linux live ISO, connect to the internet, then run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/MurderFromMars/orbitos/main/orbitos-installer.sh)
```

> WiFi? Connect first with `iwctl station wlan0 connect "YourSSID"`

---

## What You Get

**Base** — Arch Linux, linux-zen kernel, btrfs/ext4/xfs, LUKS2 encryption, GRUB

**Desktop** — KDE Plasma 6 (minimal), Wayland, SDDM or plasma-login

**Theme** — PS4 Plasma Theme, applied automatically on first login

**Toolkit** — CyberXero Toolkit, a GTK4 system management GUI built from source

**Gaming** — CachyOS gaming meta, Steam, Lutris, Heroic, Wine/Proton, MangoHud, GameMode

**Repos** — Chaotic-AUR, CachyOS (extra, extra-opt)

**Audio** — PipeWire, WirePlumber, ALSA, JACK

**Handheld** — HHD, bazzite kernel, gamescope session (Steam Deck, ROG Ally, Legion Go, etc.)

---

## Installer

Single file. Self-contained. Installs its own dependencies from the live ISO.

The TUI is built on [gum](https://github.com/charmbracelet/gum) with a custom
neon blue theme and grouped configuration panels.

**Identity** — hostname, username, passwords

**Storage** — auto or manual partitioning, filesystem, LUKS2 encryption, swap

**Region** — locale, keyboard layout, timezone

**Performance** — CachyOS optimized packages, parallel downloads

**Desktop** — login manager, AUR helper, optional packages

**Hardware** — handheld mode toggle

**Driver detection** is fully automatic via
[chwd](https://github.com/CachyOS/chwd) — Intel, AMD, NVIDIA (open/legacy),
hybrid combos, VMs, and handheld devices are all handled without user input.

---

## Handheld Mode

For Steam Deck, ROG Ally, Legion Go, GPD Win, OneXPlayer, AYA NEO, MSI Claw,
and other supported devices.

Enables HHD (Handheld Daemon) for gamepad, gyro, and TDP control. The bazzite
kernel is built from the AUR on first Plasma login (AUR builds are unreliable
inside an install chroot, so this is deferred intentionally). After the bazzite
kernel installs, linux-zen is removed and GRUB boots bazzite cleanly.

A "Return to Gaming Mode" shortcut is placed on the desktop automatically,
using the OrbitOS logo. It logs out Plasma with no confirmation dialog, returning
to the gamescope session.

---

## Encryption

LUKS2 encryption is supported on both UEFI and BIOS systems.

**UEFI** — Argon2id KDF (default). The initramfs unlocks root at boot.

**BIOS + root only** — Argon2id. initramfs handles decryption.

**BIOS + boot encryption** — pbkdf2 KDF is used automatically. GRUB cannot
decrypt Argon2id, so the installer handles this transparently.

---

## PS4 Plasma Theme

Applied automatically on first login via a one-shot KDE autostart script. It
requires a live Plasma session (qdbus6 panel scripting, KWin effect compilation,
video wallpaper activation) so it cannot be set up during install.

On first login a terminal window opens, applies the theme, and removes itself.

To re-apply manually:

```bash
bash ~/Playstation-4-Plasma/install.sh
```

---

## CyberXero Toolkit

Built from source with cargo during installation. Provides a GTK4 GUI for:

hardware driver management, optimization service toggles (ananicy-cpp, bpftune,
systemd-oomd, profile-sync-daemon), gaming meta package management, Decky Loader
integration, VM/container tooling, and auto-updates via GitHub commit hash comparison.

Launch from the app menu or run `xero-toolkit` in a terminal.

---

## System Requirements

**Minimum** — x86-64 CPU, 4 GB RAM, 40 GB storage, any GPU, BIOS or UEFI

**Recommended** — x86-64-v3+ (Ryzen 3000+ / Intel 10th gen+), 16 GB RAM,
60 GB+ NVMe, NVIDIA RTX or AMD RDNA, UEFI

---

## Post-Install

```bash
# update everything
sudo pacman -Syu

# launch the toolkit
xero-toolkit

# steam launch options
gamemoderun %command%     # performance mode
mangohud %command%        # HUD overlay
```

---

## Credits

[CachyOS](https://cachyos.org) — optimized repos, gaming meta, chwd hardware detection

[Chaotic-AUR](https://aur.chaotic.cx) — prebuilt AUR packages

DarkXero  — For motivating me to make something better 

[charmbracelet/gum](https://github.com/charmbracelet/gum) — TUI components

---

```
Made by MurderFromMars
```
