#!/usr/bin/env bash
set -e

echo "🧩 Installing Dual Audio Hub GNOME Shell Extension..."

EXT_UUID="dual-audio-hub@pardhu0547s.github.io"
INSTALL_DIR="$HOME/.local/share/gnome-shell/extensions/$EXT_UUID"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gnome_extension"

# 1. Create extension directory
mkdir -p "$INSTALL_DIR"

# 2. Copy extension files
echo "📦 Copying GNOME extension files to $INSTALL_DIR..."
cp -r "$SRC_DIR/"* "$INSTALL_DIR/"

# Copy icon.png if present
if [ -f "$(dirname "${BASH_SOURCE[0]}")/icon.png" ]; then
    cp "$(dirname "${BASH_SOURCE[0]}")/icon.png" "$INSTALL_DIR/icon.png"
fi

# 3. Enable extension version bypass (recommended for GNOME 45-51)
gsettings set org.gnome.shell disable-extension-version-validation true 2>/dev/null || true

# 4. Enable GNOME Shell extension
if command -v gnome-extensions >/dev/null 2>&1; then
    echo "⚡ Enabling GNOME Shell Extension..."
    gnome-extensions enable "$EXT_UUID" 2>/dev/null || true
fi

echo "--------------------------------------------------------"
echo "✅ Dual Audio Hub GNOME Extension installed successfully!"
echo "🎧 Look for the Headphones Icon in your GNOME Status Bar & Quick Settings Panel."
echo "💡 If it doesn't appear immediately, log out and log back in (Wayland) or press Alt+F2, type 'r', and press Enter (X11)."
echo "--------------------------------------------------------"
