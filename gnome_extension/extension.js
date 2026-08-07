/*
 * Dual Audio Hub - GNOME Shell Extension
 * Compatible with GNOME 45, 46, 47, 48, 49, 50.3+
 * https://extensions.gnome.org/
 */

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';

// Custom Quick Settings Toggle for GNOME 45+ / GNOME 50+
const DualAudioToggle = GObject.registerClass(
class DualAudioToggle extends QuickSettings.QuickMenuToggle {
    _init() {
        super._init({
            title: 'Dual Audio',
            subtitle: 'Off',
            iconName: 'audio-headphones-symbolic',
            toggleMode: true,
        });

        try {
            this.menu.setHeader('audio-headphones-symbolic', 'Dual Audio Hub', 'PipeWire Dual Bluetooth Stream');
        } catch (_) {}

        // Open Full Desktop Dashboard Button (Black & White UI)
        const appItem = new PopupMenu.PopupMenuItem('⚙ Open Desktop Dashboard');
        appItem.connect('activate', () => {
            if (this._extension) {
                this._extension._launchApp();
            }
        });
        this.menu.addMenuItem(appItem);
    }
});

export default class DualAudioExtension extends Extension {
    enable() {
        this._isStreaming = false;
        this._sinks = [];
        this._targetSink1 = null;
        this._targetSink2 = null;
        this._activeSubprocesses = [];
        this._monitorTimeoutId = 0;

        // 1. GNOME Quick Settings Integration
        try {
            this._toggle = new DualAudioToggle();
            this._toggle._extension = this;

            this._toggle.connect('clicked', () => {
                if (this._toggle.checked) {
                    this._startDualStream();
                } else {
                    this._stopDualStream();
                }
            });

            const qs = Main.panel.statusArea.quickSettings;
            if (qs) {
                if (typeof qs.addItem === 'function') {
                    qs.addItem(this._toggle);
                } else if (typeof qs._addToggle === 'function') {
                    qs._addToggle(this._toggle);
                }
            }
        } catch (e) {
            console.warn(`[Dual Audio Hub] QuickSettings toggle note: ${e}`);
        }

        // 2. Top Bar Panel Indicator (Ultra Minimal)
        try {
            this._indicator = new PanelMenu.Button(0.0, 'Dual Audio Hub', false);
            const icon = new St.Icon({
                icon_name: 'audio-headphones-symbolic',
                style_class: 'system-status-icon',
            });
            this._indicator.add_child(icon);

            const headerItem = new PopupMenu.PopupMenuItem('Dual Audio Hub', { reactive: false });
            headerItem.label.add_style_class_name('popup-subtitle-menu-item');
            this._indicator.menu.addMenuItem(headerItem);

            this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            this._panelToggleItem = new PopupMenu.PopupSwitchMenuItem('▶ Start Dual Stream', false);
            this._panelToggleItem.connect('toggled', (item, state) => {
                if (state) {
                    this._startDualStream();
                } else {
                    this._stopDualStream();
                }
            });
            this._indicator.menu.addMenuItem(this._panelToggleItem);

            this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

            const panelApp = new PopupMenu.PopupMenuItem('⚙ Open Desktop Dashboard');
            panelApp.connect('activate', () => this._launchApp());
            this._indicator.menu.addMenuItem(panelApp);

            Main.panel.addToStatusArea(this.uuid, this._indicator);
        } catch (e) {
            console.warn(`[Dual Audio Hub] Panel indicator note: ${e}`);
        }

        this._refreshSinks();
    }

    disable() {
        this._stopDualStream();

        if (this._monitorTimeoutId) {
            GLib.Source.remove(this._monitorTimeoutId);
            this._monitorTimeoutId = 0;
        }

        if (this._toggle) {
            try { this._toggle.destroy(); } catch (_) {}
            this._toggle = null;
        }

        if (this._indicator) {
            try { this._indicator.destroy(); } catch (_) {}
            this._indicator = null;
        }
    }

    _launchApp() {
        try {
            const candidatePaths = [
                GLib.build_filenamev([GLib.get_home_dir(), '.local', 'share', 'dual-audio-hub', 'dual_bt_app']),
                '/home/pavan/WorkSpace/Dual_B/dual_bt_app/build/linux/x64/debug/bundle/dual_bt_app',
                '/home/pavan/WorkSpace/Dual_B/dual_bt_app/build/linux/x64/release/bundle/dual_bt_app',
            ];
            let cmd = null;
            for (const p of candidatePaths) {
                if (GLib.file_test(p, GLib.FileTest.EXISTS)) {
                    cmd = p;
                    break;
                }
            }
            if (!cmd) cmd = 'dual_bt_app';

            const appInfo = Gio.AppInfo.create_from_commandline(cmd, 'Dual Audio Hub', Gio.AppInfoCreateFlags.NONE);
            appInfo.launch([], null);
        } catch (e) {
            console.error(`[Dual Audio Hub] Error launching app: ${e}`);
        }
    }

    _refreshSinks() {
        try {
            const proc = Gio.Subprocess.new(
                ['pw-dump'],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENT
            );

            proc.communicate_utf8_async(null, null, (obj, res) => {
                try {
                    const [, stdout] = obj.communicate_utf8_finish(res);
                    if (!stdout) return;

                    const data = JSON.parse(stdout);
                    const parsedSinks = [];

                    for (const item of data) {
                        if (item && item.type === 'PipeWire:Interface:Node') {
                            const props = (item.info && item.info.props) || {};
                            const mediaClass = props['media.class'] || '';
                            const nodeName = props['node.name'] || '';

                            if (mediaClass === 'Audio/Sink' && !nodeName.includes('Dual_Master_Sink')) {
                                const desc = props['node.description'] || nodeName;
                                const isBt = nodeName.includes('bluez') || props['device.api'] === 'bluez5';
                                parsedSinks.push({
                                    id: item.id,
                                    name: nodeName,
                                    description: desc,
                                    isBluetooth: isBt,
                                });
                            }
                        }
                    }

                    this._sinks = parsedSinks;
                    if (this._sinks.length > 0 && !this._targetSink1) this._targetSink1 = this._sinks[0];
                    if (this._sinks.length > 1 && !this._targetSink2) this._targetSink2 = this._sinks[1];
                } catch (err) {
                    console.error(`[Dual Audio Hub] Error parsing pw-dump: ${err}`);
                }
            });
        } catch (e) {
            console.error(`[Dual Audio Hub] Error refreshing sinks: ${e}`);
        }
    }

    _startDualStream() {
        if (!this._targetSink1 || !this._targetSink2) {
            // Open Desktop App so user selects sinks in the Black & White UI!
            this._launchApp();
            return;
        }

        this._stopDualStream();

        try {
            const proc1 = Gio.Subprocess.new(
                [
                    'pw-loopback',
                    '--name', 'Dual_Master_Sink',
                    '-i', 'node.name=Dual_Master_Sink media.class=Audio/Sink node.description="Dual Master"',
                    '--playback', this._targetSink1.name,
                ],
                Gio.SubprocessFlags.NONE
            );
            this._activeSubprocesses.push(proc1);

            GLib.timeout_add(GLib.PRIORITY_DEFAULT, 600, () => {
                const proc2 = Gio.Subprocess.new(
                    [
                        'pw-loopback',
                        '--name', 'Dual_Slave_Stream',
                        '--capture', 'Dual_Master_Sink',
                        '--playback', this._targetSink2.name,
                    ],
                    Gio.SubprocessFlags.NONE
                );
                this._activeSubprocesses.push(proc2);

                GLib.timeout_add(GLib.PRIORITY_DEFAULT, 600, () => {
                    this._setDefaultMasterSink();
                    return GLib.SOURCE_REMOVE;
                });

                return GLib.SOURCE_REMOVE;
            });

            this._isStreaming = true;
            if (this._toggle) {
                this._toggle.checked = true;
                this._toggle.subtitle = 'Streaming Dual Audio';
            }
            if (this._panelToggleItem) {
                this._panelToggleItem.setToggleState(true);
            }

            this._startDisconnectMonitor();
            Main.notify('Dual Audio Hub', 'Dual audio streaming active! 🎧🎧');
        } catch (e) {
            console.error(`[Dual Audio Hub] Error starting stream: ${e}`);
            this._stopDualStream();
        }
    }

    _setDefaultMasterSink() {
        try {
            const proc = Gio.Subprocess.new(
                ['pw-dump'],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENT
            );
            proc.communicate_utf8_async(null, null, (obj, res) => {
                try {
                    const [, stdout] = obj.communicate_utf8_finish(res);
                    if (!stdout) return;
                    const data = JSON.parse(stdout);
                    for (const item of data) {
                        if (item && item.type === 'PipeWire:Interface:Node') {
                            const props = (item.info && item.info.props) || {};
                            if (props['node.name'] === 'Dual_Master_Sink') {
                                Gio.Subprocess.new(['wpctl', 'set-default', String(item.id)], Gio.SubprocessFlags.NONE);
                                break;
                            }
                        }
                    }
                } catch (_) {}
            });
        } catch (_) {}
    }

    _startDisconnectMonitor() {
        if (this._monitorTimeoutId) GLib.Source.remove(this._monitorTimeoutId);

        this._monitorTimeoutId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 2, () => {
            if (!this._isStreaming) return GLib.SOURCE_REMOVE;

            const proc = Gio.Subprocess.new(
                ['pw-dump'],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENT
            );
            proc.communicate_utf8_async(null, null, (obj, res) => {
                try {
                    const [, stdout] = obj.communicate_utf8_finish(res);
                    if (!stdout) return;

                    const data = JSON.parse(stdout);
                    const currentNames = new Set();
                    for (const item of data) {
                        if (item && item.type === 'PipeWire:Interface:Node') {
                            const props = (item.info && item.info.props) || {};
                            if (props['node.name']) currentNames.add(props['node.name']);
                        }
                    }

                    const t1Ok = this._targetSink1 && currentNames.has(this._targetSink1.name);
                    const t2Ok = this._targetSink2 && currentNames.has(this._targetSink2.name);

                    if (!t1Ok || !t2Ok) {
                        const gone = !t1Ok ? this._targetSink1.description : this._targetSink2.description;
                        Main.notify('Dual Audio Hub', `Device disconnected: ${gone}. Stopped dual stream.`);
                        this._stopDualStream();
                    }
                } catch (_) {}
            });

            return GLib.SOURCE_CONTINUE;
        });
    }

    _stopDualStream() {
        if (this._monitorTimeoutId) {
            GLib.Source.remove(this._monitorTimeoutId);
            this._monitorTimeoutId = 0;
        }

        for (const proc of this._activeSubprocesses) {
            try {
                proc.force_exit();
            } catch (_) {}
        }
        this._activeSubprocesses = [];

        try {
            Gio.Subprocess.new(['pkill', '-f', 'pw-loopback.*Dual'], Gio.SubprocessFlags.NONE);
        } catch (_) {}

        this._isStreaming = false;
        if (this._toggle) {
            this._toggle.checked = false;
            this._toggle.subtitle = 'Off';
        }
        if (this._panelToggleItem) {
            this._panelToggleItem.setToggleState(false);
        }
    }
}
