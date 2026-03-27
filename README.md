<div align="center">


```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║                            ✨  O R B I T O S  ✨                              ║
║                                                                               ║
║                   Arch Linux · KDE Plasma · PS4 Theme                         ║
║                       CyberXero Toolkit · CachyOS                             ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

**A minimal, gaming-ready Arch Linux installer with a PS4-inspired KDE Plasma experience.**

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![KDE Plasma](https://img.shields.io/badge/KDE_Plasma-1D99F3?style=for-the-badge&logo=kde&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-purple?style=for-the-badge)

</div>

---

## ⚡ Install

Boot into the [Arch Linux live ISO](https://archlinux.org/download/), connect to the internet, then run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/MurderFromMars/OrbitOS/main/orbitos-installer.sh)
```

> **WiFi?** Connect first with `iwctl station wlan0 connect "YourSSID"` — then run the command above.

---

## 🧩 What You Get

| Layer | Components |
|---|---|
| **Base** | Arch Linux · linux-zen kernel · btrfs/ext4/xfs · LUKS2 encryption |
| **Desktop** | KDE Plasma (minimal) · Wayland · SDDM or plasma-login |
| **Theme** | PS4 Plasma Theme (applied automatically on first login) |
| **Toolkit** | [CyberXero Toolkit](https://github.com/synsejse/xero-toolkit) — system management GUI |
| **Gaming** | CachyOS gaming meta · Steam · Lutris · Wine · MangoHud · GameMode |
| **Repos** | XeroLinux · Chaotic-AUR · CachyOS (extra, extra-opt) |
| **Audio** | PipeWire · WirePlumber · ALSA · JACK |
| **Network** | NetworkManager · avahi · Bluetooth |

---

## 🛠️ Installer Features

- **Interactive TUI** powered by [gum](https://github.com/charmbracelet/gum)
- **Auto or manual partitioning** — dual-boot friendly
- **Full disk encryption** (LUKS2) with BIOS and UEFI support
- **Graphics auto-detection** — Intel, AMD, NVIDIA (open/legacy), hybrid combos
- **zram swap** (zstd) or swap file
- **AUR helper** — paru or yay
- **Optional packages** — Firefox, Brave, Discord, VSCodium, Steam, and more
- **CachyOS repos** — optimised x86-64-v3/v4 packages where supported
- **Self-contained** — installs its own dependencies from the live ISO

---

## 🖥️ System Requirements

| | Minimum | Recommended |
|---|---|---|
| **CPU** | x86-64 (any) | x86-64-v3+ (Ryzen 3000+ / Intel 10th gen+) |
| **RAM** | 4 GB | 16 GB |
| **Storage** | 40 GB | 60 GB+ (NVMe preferred) |
| **GPU** | Any | NVIDIA RTX / AMD RDNA |
| **Boot** | BIOS or UEFI | UEFI |

---

## 🔐 Encryption Notes

LUKS2 encryption is supported on both UEFI and BIOS systems.

- **UEFI** — Argon2id KDF (default, strong). The initramfs unlocks root at boot.
- **BIOS + root-only** — Argon2id. initramfs handles decryption.
- **BIOS + boot encryption** — pbkdf2 KDF is used automatically. GRUB cannot decrypt Argon2id, so the installer handles this for you transparently.

---

## 🎮 CachyOS Gaming Stack

OrbitOS ships the full CachyOS gaming layer on top of Arch:

- `cachyos-gaming-meta` — Steam, Lutris, Wine/Proton, GameMode, MangoHud, vkBasalt, goverlay, and more
- `cachyos-gaming-applications` — Heroic Launcher, Bottles, ProtonPlus, ProtonUp-Qt

CachyOS packages are compiled with optimisations for modern CPUs and take precedence over standard Arch packages where both exist.


---
## Cachy CHWD integration

installs and runs chwd as part of the installation script, this automatically manages drivers in the same manner as cachy meaning nvidia drivers will be setup automatically and appropriately free of user intervention as well as profiles for hybrid gpu setups optimus etc 

## 🎨 PS4 Plasma Theme

The [PS4 Plasma Theme](https://github.com/MurderFromMars/Playstation-4-Plasma) is applied automatically on first login via a one-shot KDE autostart script. It requires a live Plasma session to apply correctly (qdbus6 panel scripting, KWin effect compilation, video wallpaper activation), so it can't be set up during install.

On first login a terminal window will open, apply the theme, and remove itself. It never runs again.

To re-apply manually at any time:

```bash
bash ~/Playstation-4-Plasma/install.sh
```

---

## ⚙️ CyberXero Toolkit

Built from source during installation. Provides a GTK4 GUI for:

- Hardware driver management
- Optimization service toggles (ananicy-cpp, bpftune, systemd-oomd, profile-sync-daemon)
- Gaming meta package management
- Decky Loader integration
- VM/container tooling
- Auto-updates via GitHub commit hash comparison

Launch it from the app menu or run `xero-toolkit` in a terminal.

---

## 📋 Post-Install Checklist

```bash
# Update everything
sudo pacman -Syu

# Launch the toolkit
xero-toolkit

# Check gaming is working
gamemoderun %command%   # add to Steam launch options
mangohud %command%      # HUD overlay
```

---

## 🤝 Credits

- [XeroLinux](https://xerolinux.xyz) — toolkit foundation and repo
- [Chaotic-AUR](https://aur.chaotic.cx) — prebuilt AUR packages
- [CachyOS](https://cachyos.org) — optimised repos and gaming meta
- [charmbracelet/gum](https://github.com/charmbracelet/gum) — TUI components

---

## Why Another Arch Spin?

I grow tired of the issues of Archinstall, and wanted to create a way to conveniently create MY ideal Arch system from an Arch ISO 
as such this is highly opinonated and won't be for everyone. if you've seen my theming and such in the past then you know what this looks like. as with my themes you will need to set your own keybinds for plasma 

<div align="center">

Made with 🟣 by [MurderFromMars](https://github.com/MurderFromMars)

</div>
