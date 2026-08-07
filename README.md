# Dual Audio Hub — GNOME Shell Extension 🎧🎧

[![GNOME Shell](https://img.shields.io/badge/GNOME%20Shell-45%20--%2051-4A154B.svg?logo=gnome&logoColor=white)](https://extensions.gnome.org/)
[![PipeWire](https://img.shields.io/badge/Audio-PipeWire-blue.svg)](https://pipewire.org/)
[![Linux](https://img.shields.io/badge/OS-Linux-orange.svg?logo=linux&logoColor=black)](https://www.kernel.org/)

**Dual Audio Hub** is a native GNOME Shell Extension that lets you stream synchronized audio to two Bluetooth devices (headphones, earbuds, or speakers) simultaneously directly from your GNOME top status bar panel & Quick Settings menu via PipeWire.

---

## ✨ Features

- 🎛️ **Native GNOME Quick Settings Panel Integration**: Integrates directly inside the GNOME System Status Control Center alongside Wi-Fi, Bluetooth, Dark Style, and Night Light.
- 🎧 **1-Click Dual Audio Streaming**: Toggle dual audio streaming on/off instantly.
- 🛡️ **Auto Disconnect Protection**: Periodically monitors active PipeWire sinks. If either Bluetooth headset disconnects or powers off, streaming automatically stops, normal system audio is restored, and a GNOME desktop notification is issued.

---

## 📋 Dependencies

Your Linux system must be running **GNOME Shell 45+** (Standard default on Fedora 39/40/41/42+, Ubuntu 23.10/24.04/24.10+, Debian 12+, Arch Linux) with **PipeWire**.

The extension relies on PipeWire utilities (`pw-loopback`, `pw-link`, `pw-dump`, `wpctl`) to route and sync the audio perfectly. Make sure you have the required packages installed for your distribution:

**Ubuntu / Debian:**
```bash
sudo apt install pipewire wireplumber bluez pipewire-bin
```

**Fedora:**
```bash
sudo dnf install pipewire wireplumber bluez pipewire-utils
```

**Arch Linux:**
```bash
sudo pacman -S pipewire wireplumber bluez
```

---

## 🚀 Installation

### 1-Click Automated Installer

```bash
git clone https://github.com/Pardhu0547s/Dual_Bluetooth_Linux.git
cd Dual_Bluetooth_Linux
bash install.sh
```

---

## 📖 How to Use

1. **Connect Bluetooth Devices**: Pair and connect both Bluetooth headphones/speakers in your GNOME Bluetooth settings.
2. **Open Quick Settings**: Open the GNOME Quick Settings menu (top right corner of your screen).
3. **Select Devices**: Click the arrow next to the **Dual Audio** toggle to reveal the sub-menu. You can select your two Bluetooth devices here and independently adjust their volumes.
4. **Stream**: Turn on the Dual Audio toggle to start streaming perfectly synchronized audio to both devices!

*(Note: On Wayland, you may need to log out and log back into your user session after running the installer for the GNOME shell to load the extension properly).*
