/*
 * Dual Audio Hub - GNOME Shell Extension
 * Fully compliant with GNOME 45+ ESM Extension Standards
 * https://extensions.gnome.org/
 */

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

export default class DualAudioExtension extends Extension {
    enable() {
        this._indicator = new PanelMenu.Button(0.0, 'Dual Audio Hub', false);

        // Top bar icon
        const icon = new St.Icon({
            icon_name: 'audio-headphones-symbolic',
            style_class: 'system-status-icon',
        });
        this._indicator.add_child(icon);

        // Header Item
        const headerItem = new PopupMenu.PopupMenuItem('Dual Audio Hub', { reactive: false });
        headerItem.label.add_style_class_name('popup-subtitle-menu-item');
        this._indicator.menu.addMenuItem(headerItem);

        this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Toggle Switch Item
        this._toggleItem = new PopupMenu.PopupSwitchMenuItem('Dual Bluetooth Stream', false);
        this._toggleItem.connect('toggled', (item, state) => {
            if (state) {
                this._startDualStream();
            } else {
                this._stopDualStream();
            }
        });
        this._indicator.menu.addMenuItem(this._toggleItem);

        this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Open Full Desktop App Button
        const appItem = new PopupMenu.PopupMenuItem('⚙ Open Dual Audio Dashboard');
        appItem.connect('activate', () => {
            this._launchApp();
        });
        this._indicator.menu.addMenuItem(appItem);

        // Add to GNOME Shell Top Bar
        Main.panel.addToStatusArea(this.uuid, this._indicator);
        this._activeSubprocesses = [];
    }

    disable() {
        this._stopDualStream();

        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }

        this._toggleItem = null;
        this._activeSubprocesses = [];
    }

    _getPythonScriptPath() {
        const candidatePaths = [
            '/home/pavan/WorkSpace/Dual_B/dual_bt_transmitter.py',
            GLib.build_filenamev([this.path, 'dual_bt_transmitter.py']),
            GLib.build_filenamev([this.path, '..', 'dual_bt_transmitter.py']),
        ];
        for (const p of candidatePaths) {
            if (GLib.file_test(p, GLib.FileTest.EXISTS)) return p;
        }
        return '/home/pavan/WorkSpace/Dual_B/dual_bt_transmitter.py';
    }

    _getAppBinaryPath() {
        const candidatePaths = [
            '/home/pavan/WorkSpace/Dual_B/dual_bt_app/build/linux/x64/debug/bundle/dual_bt_app',
            '/home/pavan/WorkSpace/Dual_B/dual_bt_app/build/linux/x64/release/bundle/dual_bt_app',
            GLib.build_filenamev([this.path, '..', 'dual_bt_app', 'build', 'linux', 'x64', 'debug', 'bundle', 'dual_bt_app']),
            GLib.build_filenamev([this.path, '..', 'dual_bt_app', 'build', 'linux', 'x64', 'release', 'bundle', 'dual_bt_app']),
        ];

        for (const p of candidatePaths) {
            if (GLib.file_test(p, GLib.FileTest.EXISTS)) return p;
        }

        const sysProg = GLib.find_program_in_path('dual_bt_app');
        if (sysProg) return sysProg;

        return null;
    }

    _startDualStream() {
        try {
            const scriptPath = this._getPythonScriptPath();
            const proc = Gio.Subprocess.new(
                ['python3', scriptPath],
                Gio.SubprocessFlags.NONE
            );
            this._activeSubprocesses.push(proc);
        } catch (e) {
            console.error(`[Dual Audio Hub] Error starting dual stream: ${e}`);
        }
    }

    _stopDualStream() {
        for (const proc of this._activeSubprocesses) {
            try {
                proc.force_exit();
            } catch (_) {}
        }
        this._activeSubprocesses = [];

        try {
            Gio.Subprocess.new(['pkill', '-f', 'pw-loopback.*Dual'], Gio.SubprocessFlags.NONE);
        } catch (_) {}
    }

    _launchApp() {
        try {
            const appPath = this._getAppBinaryPath();
            let cmd = appPath;
            if (!cmd) {
                const scriptPath = this._getPythonScriptPath();
                cmd = `python3 ${scriptPath}`;
            }

            const appInfo = Gio.AppInfo.create_from_commandline(cmd, 'Dual Audio Hub', Gio.AppInfoCreateFlags.NONE);
            appInfo.launch([], null);
        } catch (e) {
            console.error(`[Dual Audio Hub] Error launching application: ${e}`);
        }
    }
}
