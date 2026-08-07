#!/usr/bin/env bash
set -e

echo "🎧 Installing Dual Audio Hub (Desktop App + GNOME Extension)..."

INSTALL_DIR="$HOME/.local/share/dual-audio-hub"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ICON_DIR="$HOME/.local/share/icons"
DESKTOP_DIR="$HOME/.local/share/applications"
EXT_UUID="dual-audio-hub@pardhu0547s.github.io"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"

# Create directories
mkdir -p "$INSTALL_DIR"
mkdir -p "$ICON_DIR"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$EXT_DIR"

# 1. Build release binary if not present
if [ ! -f "$APP_DIR/dual_bt_app/build/linux/x64/release/bundle/dual_bt_app" ]; then
    echo "🔨 Building Flutter Linux Desktop App..."
    cd "$APP_DIR/dual_bt_app"
    flutter build linux --release
    cd "$APP_DIR"
fi

# 2. Copy application bundle
echo "📦 Installing Desktop Application files to $INSTALL_DIR..."
cp -r "$APP_DIR/dual_bt_app/build/linux/x64/release/bundle/"* "$INSTALL_DIR/"

# 3. Copy icon
echo "🖼️ Installing application icon..."
if [ -f "$APP_DIR/icon.png" ]; then
    cp "$APP_DIR/icon.png" "$ICON_DIR/org.dualbt.DualAudioHub.png"
fi

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

# 5. Install GNOME Shell Extension
if [ -d "$APP_DIR/gnome_extension" ]; then
    echo "🧩 Installing GNOME Shell Extension..."
    cp -r "$APP_DIR/gnome_extension/"* "$EXT_DIR/"
    if [ -f "$APP_DIR/icon.png" ]; then
        cp "$APP_DIR/icon.png" "$EXT_DIR/icon.png"
    fi
    gsettings set org.gnome.shell disable-extension-version-validation true 2>/dev/null || true
    if command -v gnome-extensions >/dev/null 2>&1; then
        gnome-extensions enable "$EXT_UUID" 2>/dev/null || true
    fi
fi

echo "--------------------------------------------------------"
echo "✅ Dual Audio Hub installed successfully!"
echo "📱 Open 'Dual Audio Hub' from your Linux Application Menu!"
echo "🎧 Or toggle streaming directly from GNOME Quick Settings!"
echo "--------------------------------------------------------"
