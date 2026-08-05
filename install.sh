#!/usr/bin/env bash
set -e

echo "🎧 Installing Dual Audio Hub for Linux..."

# Define installation directories
INSTALL_DIR="$HOME/.local/share/dual-audio-hub"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_DIR="$HOME/.local/share/applications"

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$ICON_DIR"
mkdir -p "$DESKTOP_DIR"

# 1. Build release binary if not present
if [ ! -f "$APP_DIR/dual_bt_app/build/linux/x64/release/bundle/dual_bt_app" ]; then
    echo "🔨 Building release binary..."
    cd "$APP_DIR/dual_bt_app"
    flutter build linux --release
    cd "$APP_DIR"
fi

# 2. Copy application bundle
echo "📦 Installing application files to $INSTALL_DIR..."
cp -r "$APP_DIR/dual_bt_app/build/linux/x64/release/bundle/"* "$INSTALL_DIR/"

# 3. Copy icon
echo "🖼️ Installing application icon..."
cp "$APP_DIR/icon.png" "$ICON_DIR/org.dualbt.DualAudioHub.png"

# 4. Create Desktop Launcher Entry
echo "🚀 Creating desktop launcher..."
cat << EOF > "$DESKTOP_DIR/org.dualbt.DualAudioHub.desktop"
[Desktop Entry]
Name=Dual Audio Hub
Comment=Stream synchronized audio to dual Bluetooth headphones on Linux
Exec=$INSTALL_DIR/dual_bt_app
Icon=$ICON_DIR/org.dualbt.DualAudioHub.png
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Mixer;
Keywords=bluetooth;audio;dual;pipewire;
EOF

chmod +x "$DESKTOP_DIR/org.dualbt.DualAudioHub.desktop"

# 5. Optionally install GNOME Shell Extension
GNOME_EXT_DIR="$HOME/.local/share/gnome-shell/extensions/dual-audio-hub@pardhu0547s.github.io"
if [ -d "$APP_DIR/gnome_extension" ]; then
    echo "🧩 Installing GNOME Shell Extension..."
    mkdir -p "$GNOME_EXT_DIR"
    cp -r "$APP_DIR/gnome_extension/"* "$GNOME_EXT_DIR/"
    gsettings set org.gnome.shell disable-extension-version-validation true 2>/dev/null || true
    echo "💡 Note: You can enable the extension by running: gnome-extensions enable dual-audio-hub@pardhu0547s.github.io"
fi

echo "✅ Dual Audio Hub installed successfully!"
echo "🎉 You can now open 'Dual Audio Hub' from your Linux application menu or terminal."
