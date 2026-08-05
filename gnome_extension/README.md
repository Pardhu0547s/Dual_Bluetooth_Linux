# Dual Audio Hub - GNOME Shell Extension 🧩

A top-bar GNOME Shell Extension for **Dual Audio Hub** that provides a 1-click quick toggle and dashboard launcher directly inside the GNOME status panel.

---

## 🛠️ Installation & Testing

To install the extension locally on GNOME 45 / 46 / 47:

```bash
mkdir -p ~/.local/share/gnome-shell/extensions/
cp -r gnome_extension ~/.local/share/gnome-shell/extensions/dual-audio-hub@pardhu0547s.github.io
```

### Enable the Extension
```bash
gnome-extensions enable dual-audio-hub@pardhu0547s.github.io
```
*(Or use the **GNOME Extensions** app).*

---

## 📋 Compliance & Guidelines Check

This extension is built according to **extensions.gnome.org (EGO)** official review guidelines:
- ✅ **GNOME 45+ ESM Import Syntax** (`resource:///org/gnome/shell/...` and `gi://...`).
- ✅ **Clean Memory & Process Lifecycle**: All UI objects, D-Bus listeners, and subprocesses are cleanly destroyed on `disable()`.
- ✅ **Non-blocking Asynchronous Calls**: Uses `Gio.Subprocess` to ensure the GNOME main UI thread never freezes.
- ✅ **No Bundled Binaries**: Uses system PipeWire and D-Bus APIs.
