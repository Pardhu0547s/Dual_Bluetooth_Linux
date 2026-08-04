<<<<<<< HEAD
# Dual_Bluetooth_Linux
=======
# Dual Bluetooth Audio Hub for Linux 🎧🎧

[![Linux](https://img.shields.io/badge/OS-Linux-orange.svg)](https://www.kernel.org/)
[![PipeWire](https://img.shields.io/badge/Audio-PipeWire-blue.svg)](https://pipewire.org/)
[![Flutter](https://img.shields.io/badge/UI-Flutter%20Desktop-02569B.svg)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Backend-Python%203-3776AB.svg)](https://www.python.org/)

**Dual Bluetooth Audio Hub** is a Linux application that connects two Bluetooth audio devices (headphones, earbuds, or speakers) simultaneously and transmits the exact same audio signal to both devices with real-time latency alignment.

---

## ✨ Features

- 🎧 **Simultaneous Dual Streaming**: Stream audio to 2 Bluetooth devices (A2DP) at the same time.
- 🎛️ **PipeWire Virtual Master Router**: Dynamically creates a virtual master sink (`Dual_Master_Sink`) and switches system default audio output so all apps (YouTube, Spotify, VLC, Chrome, system sound) stream to both headsets effortlessly.
- ⏱️ **Latency Delay Alignment**: Independent millisecond delay sliders (0 - 500 ms) per device to compensate for hardware decoding lag and keep audio in sync.
- 📱 **Native Flutter GTK App**: Modern glassmorphic desktop interface with dark theme and live connection indicators.
- 🌐 **Python Web Dashboard**: Lightweight fallback web dashboard accessible via browser (`http://localhost:5050`).
- 🔄 **Auto Sink Restoration**: Automatically restores your original default system audio output when streaming stops.

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

## 🚀 Installation & Setup

### 1. Clone the Repository
```bash
git clone https://github.com/Pardhu0547s/Dual_Bluetooth_Linux.git
cd Dual_Bluetooth_Linux
```

---

### Option A: Native Flutter Desktop App (Recommended)

#### 1. Build the App
```bash
cd dual_bt_app
flutter build linux --release
```

#### 2. Run the App
```bash
./build/linux/x64/release/bundle/dual_bt_app
```

---

### Option B: Python Web GUI Dashboard (No Build Needed)

If you don't have Flutter installed, you can launch the Python Web Interface:

```bash
python3 dual_bt_transmitter.py
```

Then open your browser and navigate to:
👉 **[http://localhost:5050](http://localhost:5050)**

---

## 📖 How to Use

1. **Connect Bluetooth Devices**: Pair and connect both Bluetooth headphones/speakers in your Linux system Bluetooth settings (or via `bluetoothctl connect <MAC>`).
2. **Launch Application**: Open the **Dual Audio Hub** (Flutter app or Web interface).
3. **Select Sinks**:
   - **Device 1**: Choose Headphones A (e.g. *Boult Audio Maverick*).
   - **Device 2**: Choose Headphones B (e.g. *CLOCK*).
4. **Start Streaming**: Click **▶ Start Dual Bluetooth Stream**.
5. **Adjust Latency**: If one headset lags behind slightly, adjust the **Latency Delay** slider for that device to align them perfectly.

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
>>>>>>> ebc3676 (Initial commit: Dual Bluetooth Audio Hub for Linux with PipeWire engine, Flutter desktop UI, and Python web GUI)
