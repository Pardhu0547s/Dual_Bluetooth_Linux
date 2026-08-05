# Dual Bluetooth Audio Hub for Linux 🎧🎧

[![Linux](https://img.shields.io/badge/OS-Linux-orange.svg?logo=linux&logoColor=black)](https://www.kernel.org/)
[![PipeWire](https://img.shields.io/badge/Audio-PipeWire-blue.svg)](https://pipewire.org/)
[![Flutter](https://img.shields.io/badge/UI-Flutter%20Desktop-02569B.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![GNOME](https://img.shields.io/badge/Extension-GNOME%20Shell-4A154B.svg)](https://extensions.gnome.org/)
[![Python](https://img.shields.io/badge/Backend-Python%203-3776AB.svg?logo=python&logoColor=white)](https://www.python.org/)

**Dual Bluetooth Audio Hub** is a Linux application and GNOME extension designed to stream synchronized audio to two Bluetooth audio devices (headphones, earbuds, or speakers) simultaneously with independent volume controls and automatic disconnect protection.

---

## ✨ Features

- 🎧 **Simultaneous Dual Streaming**: Stream high-quality audio to 2 Bluetooth headsets or speakers at the same time.
- 🎛️ **PipeWire Virtual Master Router**: Dynamically creates a virtual master sink (`Dual_Master_Sink`) and switches system default audio output so all media apps (YouTube, Spotify, VLC, Chrome, system sounds) play to both devices.
- 🔊 **Independent Device Volume**: Adjust the hardware volume of Headphones A and Headphones B independently (0% – 100%) using `wpctl`.
- 🛡️ **Auto Disconnect Protection**: Periodically monitors active PipeWire sinks. If a Bluetooth headset disconnects or powers off, the app automatically stops streaming, restores your default system audio output (e.g., Laptop Speakers), and exits cleanly.
- 🎨 **Modern High-Contrast UI**: Sleek GTK interface with dark/light contrasting device cards, metallic branding, and live connection status indicators.
- 🧩 **GNOME Shell Top-Bar Extension**: 1-click quick toggle panel right inside your GNOME system tray.
- 🌐 **Python Web Dashboard**: Lightweight standalone web GUI fallback accessible via browser (`http://localhost:5050`).

---

## 📋 Prerequisites & System Requirements

Your Linux distribution should use **PipeWire** (standard default on Ubuntu 22.04+, Fedora 34+, Arch Linux, Debian 12+, Pop!_OS):

### Required System Packages:
- `pipewire` & `wireplumber`
- `bluez` / `bluetoothctl`
- `python3`
- `flutter` *(Only if building the desktop app from source)*

Check if PipeWire is active on your system:
```bash
wpctl status
```

---

## 🚀 Installation & Setup

### ⚡ 1-Click Automated Installer (Recommended)

To install the desktop application, launcher entry, app icon, and GNOME Shell Extension automatically:

```bash
git clone https://github.com/Pardhu0547s/Dual_Bluetooth_Linux.git
cd Dual_Bluetooth_Linux
bash install.sh
```

---

### Option A: Manual Flutter Desktop Build

#### 1. Build the Application:
```bash
cd dual_bt_app
flutter build linux --release
```

#### 2. Launch the Application:
```bash
./build/linux/x64/release/bundle/dual_bt_app
```

---

### Option B: GNOME Shell Top-Bar Extension (GNOME 45 – 50+)

If you use Fedora, Ubuntu, or any GNOME desktop environment:

#### 1. Install Extension Files:
```bash
mkdir -p ~/.local/share/gnome-shell/extensions/
cp -r gnome_extension ~/.local/share/gnome-shell/extensions/dual-audio-hub@pardhu0547s.github.io
```

#### 2. Enable Extension Version Bypass (Recommended for Fedora / Rawhide):
```bash
gsettings set org.gnome.shell disable-extension-version-validation true
```

#### 3. Enable the Extension:
```bash
gnome-extensions enable dual-audio-hub@pardhu0547s.github.io
```

A **Headphones Icon** will appear in your GNOME top status bar for 1-click dual audio streaming!

---

### Option C: Python Web Dashboard (No Build Required)

If you prefer a lightweight single-script web dashboard:

```bash
python3 dual_bt_transmitter.py
```

Then open your browser and navigate to:
👉 **[http://localhost:5050](http://localhost:5050)**

---

## 📖 How to Use

1. **Connect Bluetooth Devices**: Pair and connect both Bluetooth headphones/speakers in your system Bluetooth settings (or via `bluetoothctl connect <MAC>`).
2. **Launch Application**: Open **Dual Audio Hub** (from Application Menu, Desktop app, GNOME top bar menu, or Web dashboard).
3. **Select Sinks**:
   - **Device 1**: Choose Headphones A (Primary Output).
   - **Device 2**: Choose Headphones B (Secondary Output).
4. **Start Streaming**: Click **▶ Start Dual Stream**.
5. **Adjust Volume**: Use the **VOLUME** sliders to set custom hardware volume per device.

---

## 📁 Project Structure

```
Dual_Bluetooth_Linux/
├── dual_bt_app/              # Native Flutter GTK Desktop Application
│   ├── assets/               # Image assets (image.png header logo, icon.png app icon)
│   ├── lib/
│   │   ├── main.dart         # Entry point
│   │   ├── models/           # AudioSink data model
│   │   ├── services/         # PipeWire Linux service
│   │   └── ui/               # Desktop UI & Theme system
│   └── linux/                # Linux GTK Runner files
├── gnome_extension/          # GNOME Shell Top-Bar Extension
├── install.sh                # 1-Click Automated Installer script
├── dual_bt_transmitter.py    # Standalone Python Web GUI Dashboard
├── releases/                 # Pre-built release binaries
└── README.md
```

---

## 🛠️ CLI / Pure Terminal Commands

If you prefer running PipeWire dual loopbacks directly from terminal:

```bash
# 1. Start Master Sink (outputs to Target 1)
pw-loopback --name Dual_Master_Sink -i 'node.name=Dual_Master_Sink media.class=Audio/Sink node.description="Dual Master"' --playback <TARGET_SINK_1_NAME> &

# 2. Start Slave Stream (captures from Master, outputs to Target 2)
pw-loopback --name Dual_Slave_Stream --capture Dual_Master_Sink --playback <TARGET_SINK_2_NAME> &

# 3. Set Dual_Master_Sink as default output device
wpctl set-default <DUAL_MASTER_SINK_ID>
```

To stop:
```bash
killall pw-loopback
```
