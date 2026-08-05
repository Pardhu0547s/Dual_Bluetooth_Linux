# Dual Bluetooth Audio Hub 🎧🎧

[![Linux](https://img.shields.io/badge/Linux-PipeWire-FCC624.svg?logo=linux&logoColor=black)](https://pipewire.org/)
[![macOS](https://img.shields.io/badge/macOS-CoreAudio-000000.svg?logo=apple&logoColor=white)](https://developer.apple.com/documentation/coreaudio)
[![Windows](https://img.shields.io/badge/Windows-WASAPI-0078D6.svg?logo=windows&logoColor=white)](https://learn.microsoft.com/en-us/windows/win32/coreaudio/wasapi)
[![Flutter](https://img.shields.io/badge/UI-Flutter-02569B.svg?logo=flutter&logoColor=white)](https://flutter.dev)
[![GNOME](https://img.shields.io/badge/Extension-GNOME%20Shell-4A154B.svg)](https://extensions.gnome.org/)

**Dual Audio Hub** is a cross-platform application that streams the same audio to two Bluetooth devices (headphones, earbuds, or speakers) simultaneously — with independent volume control per device.

---

## ✨ Features

| Feature | Linux | macOS | Windows | Android/iOS |
|:---|:---:|:---:|:---:|:---:|
| Dual Bluetooth Streaming | ✅ | ✅ | ✅ | Guide Only |
| Individual Volume Control | ✅ | ✅ | ✅ | — |
| Auto Disconnect Detection | ✅ | ✅ | ✅ | — |
| Default Sink Restoration | ✅ | ✅ | ✅ | — |
| GNOME Shell Extension | ✅ | — | — | — |
| Python Web Dashboard | ✅ | ✅ | ✅ | — |

### Key Highlights:
- 🎛️ **Virtual Master Audio Router**: Creates a virtual master sink and switches system default audio output so all apps (YouTube, Spotify, VLC, Chrome) stream to both headsets effortlessly
- 🔊 **Independent Volume**: Adjust each headphone's volume separately (0% – 100%)
- 🛡️ **Auto Protection**: Detects Bluetooth disconnection, stops streaming, restores normal audio, and exits cleanly
- 🎨 **Professional Dark UI**: Consistent glassmorphic design across every platform

---

## 📋 System Requirements

### Linux
- PipeWire + WirePlumber (standard on Ubuntu 22.04+, Fedora 34+, Arch, Debian 12+)
- BlueZ (`bluetoothctl`)

### macOS
- macOS 12 Monterey or later
- CoreAudio (built-in)

### Windows
- Windows 10/11
- WASAPI (built-in)

### Mobile (Guide Only)
- **Android**: Samsung Galaxy with Dual Audio, or Android 13+ with LE Audio hardware
- **iOS**: AirPods / Beats with Audio Sharing (iPhone 8+, iOS 13+)

---

## 🚀 Installation

### Clone the Repository
```bash
git clone https://github.com/Pardhu0547s/Dual_Bluetooth_Linux.git
cd Dual_Bluetooth_Linux
```

---

### Option 1: Flutter Desktop App (All Platforms)

#### Build
```bash
cd dual_bt_app

# Linux
flutter build linux --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

#### Run
```bash
# Linux
./build/linux/x64/release/bundle/dual_bt_app

# macOS
open build/macos/Build/Products/Release/dual_bt_app.app

# Windows
.\build\windows\x64\runner\Release\dual_bt_app.exe
```

---

### Option 2: GNOME Shell Extension (Linux GNOME 45–50+)

```bash
# Install extension files
mkdir -p ~/.local/share/gnome-shell/extensions/
cp -r gnome_extension ~/.local/share/gnome-shell/extensions/dual-audio-hub@pardhu0547s.github.io

# Bypass version validation (recommended for Fedora / Rawhide)
gsettings set org.gnome.shell disable-extension-version-validation true

# Enable extension
gnome-extensions enable dual-audio-hub@pardhu0547s.github.io
```

---

### Option 3: Python Web Dashboard (No Build Required)

```bash
python3 dual_bt_transmitter.py
```
Open **[http://localhost:5050](http://localhost:5050)** in your browser.

---

### Option 4: Android / iOS (Guide Only)

```bash
cd dual_bt_app

# Android APK
flutter build apk --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

> **Note**: The mobile app shows step-by-step instructions for enabling your device's built-in dual audio features (Samsung Dual Audio, Apple Audio Sharing, LE Audio Auracast). Programmatic dual routing is not supported on mobile platforms.

---

## 📖 How to Use

1. **Connect** both Bluetooth headphones/speakers in your system Bluetooth settings
2. **Launch** Dual Audio Hub (Desktop app, GNOME extension, or Web dashboard)
3. **Select** Device 1 and Device 2 from the dropdown sinks
4. **Start** dual streaming with the master control button
5. **Adjust** individual volume sliders as needed

---

## 🏗️ Architecture

```
                    ┌──────────────────────────┐
                    │   Flutter UI (Dart)       │
                    │   Same polished UI on     │
                    │   every platform          │
                    └──────────┬───────────────┘
                               │ Platform Channels
         ┌─────────────────────┼─────────────────────┐
         ▼                     ▼                     ▼
  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
  │ Linux Engine │    │ macOS Engine │    │ Windows Eng. │
  ├──────────────┤    ├──────────────┤    ├──────────────┤
  │ PipeWire     │    │ CoreAudio    │    │ WASAPI       │
  │ pw-loopback  │    │ Aggregate    │    │ Loopback +   │
  │ wpctl        │    │ Multi-Output │    │ Dual Render  │
  └──────────────┘    └──────────────┘    └──────────────┘
```

---

## 📁 Project Structure

```
Dual_Bluetooth_Linux/
├── dual_bt_app/              # Flutter cross-platform desktop app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/           # AudioSink data model
│   │   ├── services/         # Platform-specific audio backends
│   │   │   ├── audio_service.dart          # Abstract interface
│   │   │   ├── audio_service_factory.dart  # Platform factory
│   │   │   ├── linux_audio_service.dart    # PipeWire backend
│   │   │   ├── macos_audio_service.dart    # CoreAudio backend
│   │   │   ├── windows_audio_service.dart  # WASAPI backend
│   │   │   └── mobile_guide_service.dart   # Android/iOS stub
│   │   └── ui/               # Shared polished UI
│   │       ├── theme.dart             # Design system
│   │       ├── home_screen.dart       # Main dashboard
│   │       └── mobile_guide_screen.dart  # Mobile instructions
│   ├── linux/                # Linux GTK runner
│   ├── macos/                # macOS runner + CoreAudio plugin
│   ├── windows/              # Windows runner + WASAPI plugin
│   └── android/ & ios/       # Mobile runners
├── gnome_extension/          # GNOME Shell top-bar extension
├── dual_bt_transmitter.py    # Python web dashboard fallback
└── README.md
```

---

## 📄 License
MIT License
