# Dual Bluetooth Audio Hub for Linux 🎧🎧

[![Linux](https://img.shields.io/badge/OS-Linux-orange.svg)](https://www.kernel.org/)
[![PipeWire](https://img.shields.io/badge/Audio-PipeWire-blue.svg)](https://pipewire.org/)
[![Flutter](https://img.shields.io/badge/UI-Flutter%20Desktop-02569B.svg)](https://flutter.dev)
[![GNOME](https://img.shields.io/badge/Extension-GNOME%20Shell-4A154B.svg)](https://extensions.gnome.org/)
[![Python](https://img.shields.io/badge/Backend-Python%203-3776AB.svg)](https://www.python.org/)

**Dual Bluetooth Audio Hub** is a Linux application, GNOME extension, and utility that connects two Bluetooth audio devices (headphones, earbuds, or speakers) simultaneously and streams the exact same audio signal to both devices in sync.

---

## ✨ Features

- 🎧 **Simultaneous Dual Streaming**: Stream audio to 2 Bluetooth devices (A2DP) at the same time.
- 🎛️ **PipeWire Virtual Master Router**: Dynamically creates a virtual master sink (`Dual_Master_Sink`) and switches system default audio output so all apps (YouTube, Spotify, VLC, Chrome, system sound) stream to both headsets effortlessly.
- 🔊 **Individual Volume Control**: Adjust the volume of Headphones A and Headphones B independently (0% – 100%).
- 🛡️ **Auto Disconnect Protection**: Automatically detects if a Bluetooth device is turned off or disconnected, stops streaming, restores your default audio output (e.g., Laptop Speakers), and safely turns off.
- 📱 **Native Flutter Desktop App**: Modern glassmorphic desktop interface with dark theme and live connection indicators.
- 🧩 **GNOME Shell Top-Bar Extension**: 1-click toggle and dashboard launcher right inside your GNOME system panel.
- 🌐 **Python Web Dashboard**: Lightweight fallback web dashboard accessible via browser (`http://localhost:5050`).

---

## 📋 Prerequisites & System Requirements

Your Linux distribution should use **PipeWire** (standard default on Ubuntu 22.04+, Fedora 34+, Arch Linux, Debian 12+, Pop!_OS):

### System Packages:
- `pipewire` & `wireplumber`
- `bluez` / `bluetoothctl`
- `python3`
- `flutter` *(Only if compiling the native desktop app from source)*

To check if PipeWire is running:
```bash
wpctl status
```

---

## 🚀 Installation & Usage Options

First, clone the repository:
```bash
git clone https://github.com/Pardhu0547s/Dual_Bluetooth_Linux.git
cd Dual_Bluetooth_Linux
```

---

### Option 1: Native Flutter Desktop App (Recommended)

#### 1. Build the Application:
```bash
cd dual_bt_app
flutter build linux --release
```

#### 2. Run the Desktop App:
```bash
./build/linux/x64/release/bundle/dual_bt_app
```

---

### Option 2: GNOME Shell Top-Bar Extension (For GNOME 45 / 46 / 47 / 50+)

If you use Fedora, Ubuntu, or any GNOME desktop, you can install the top-bar extension:

#### 1. Install Extension Files:
```bash
mkdir -p ~/.local/share/gnome-shell/extensions/
cp -r gnome_extension ~/.local/share/gnome-shell/extensions/dual-audio-hub@pardhu0547s.github.io
```

#### 2. Enable GNOME Version Mismatch Bypass (Recommended for Fedora / Rawhide):
```bash
gsettings set org.gnome.shell disable-extension-version-validation true
```

#### 3. Enable Extension:
```bash
gnome-extensions enable dual-audio-hub@pardhu0547s.github.io
```

A **Headphones Icon** will now appear in your GNOME top status bar for 1-click quick toggled dual audio streaming!

---

### Option 3: Python Web Dashboard (No Build Required)

If you don't have Flutter installed, you can launch the Python web interface:

```bash
python3 dual_bt_transmitter.py
```

Then open your browser and navigate to:
👉 **[http://localhost:5050](http://localhost:5050)**

---

## 📖 How to Use

1. **Connect Bluetooth Devices**: Pair and connect both Bluetooth headphones/speakers in your Linux system Bluetooth settings (or via `bluetoothctl connect <MAC>`).
2. **Launch Application**: Open the **Dual Audio Hub** (Flutter app, GNOME top bar menu, or Web interface).
3. **Select Sinks**:
   - **Device 1**: Choose Headphones A (e.g. *Boult Audio Maverick*).
   - **Device 2**: Choose Headphones B (e.g. *trüke Buds Q1 Plus*).
4. **Start Streaming**: Click **▶ Start Dual Bluetooth Stream**.
5. **Adjust Volume**: Slide the **Device Volume** sliders to set custom volumes for each headphone independently.

---

## 🛠️ CLI / Terminal Pure Commands

If you prefer using pure terminal commands without a GUI:

```bash
# 1. Start Master Sink (outputs to Target 1)
pw-loopback --name Dual_Master_Sink -i 'node.name=Dual_Master_Sink media.class=Audio/Sink node.description="Dual Bluetooth Master"' --playback <TARGET_SINK_1_NAME> &

# 2. Start Slave Stream (captures from Master, outputs to Target 2)
pw-loopback --name Dual_Slave_Stream --capture Dual_Master_Sink --playback <TARGET_SINK_2_NAME> &

# 3. Set Dual_Master_Sink as default output device
wpctl set-default <DUAL_MASTER_SINK_ID>
```

To stop:
```bash
killall pw-loopback
```

---

## 📄 License
MIT License
