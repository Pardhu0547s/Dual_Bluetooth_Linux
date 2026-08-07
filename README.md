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

## 📋 Prerequisites

Your Linux system must be running **GNOME Shell 45+** (Standard default on Fedora 39/40/41/42+, Ubuntu 23.10/24.04/24.10+, Debian 12+, Arch Linux) with **PipeWire**.

Required tools:
- `pipewire` & `wireplumber`
- `bluez` / `bluetoothctl`

Check if PipeWire is running:
```bash
wpctl status
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
2. **Toggle Dual Audio**: Click the **Dual Audio** toggle inside your GNOME Quick Settings menu or top status bar.

---

## 📁 Project Structure

```
Dual_Bluetooth_Linux/
├── gnome_extension/
│   ├── extension.js          # Native QuickSettings ESM GNOME Extension module
│   ├── metadata.json         # Extension metadata & shell version support (45-51)
│   ├── stylesheet.css        # Extension menu styles
│   └── icon.png              # Custom 3D split headphone icon asset
├── install.sh                # Automated installer script
└── README.md
```
