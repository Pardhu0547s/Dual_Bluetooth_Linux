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
        this._isStreaming = false;
        this._sinks = [];
        this._targetSink1 = null;
        this._targetSink2 = null;
        this._vol1 = 1.0;
        this._vol2 = 1.0;
        this._monitorTimeoutId = 0;
        this._activeSubprocesses = [];

        // Top Bar Indicator Button
        this._indicator = new PanelMenu.Button(0.0, 'Dual Audio Hub', false);

        // Top bar icon
        this._icon = new St.Icon({
            icon_name: 'audio-headphones-symbolic',
            style_class: 'system-status-icon',
        });
        this._indicator.add_child(this._icon);

        // Header Item
        const headerItem = new PopupMenu.PopupMenuItem('Dual Audio Hub (PipeWire)', { reactive: false });
        headerItem.label.add_style_class_name('popup-subtitle-menu-item');
        this._indicator.menu.addMenuItem(headerItem);

        this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Master Toggle Switch
        this._toggleItem = new PopupMenu.PopupSwitchMenuItem('▶ Start Dual Stream', false);
        this._toggleItem.connect('toggled', (item, state) => {
            if (state) {
                this._startDualStream();
            } else {
                this._stopDualStream();
            }
        });
        this._indicator.menu.addMenuItem(this._toggleItem);

        this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Submenus for Sinks Selection
        this._menuSink1 = new PopupMenu.PopupSubMenuMenuItem('🎧 Device 1 (Primary Output)');
        this._menuSink2 = new PopupMenu.PopupSubMenuMenuItem('🎧 Device 2 (Secondary Output)');
        this._indicator.menu.addMenuItem(this._menuSink1);
        this._indicator.menu.addMenuItem(this._menuSink2);

        this._indicator.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Rescan Sinks Item
        const rescanItem = new PopupMenu.PopupMenuItem('🔄 Rescan Audio Devices');
        rescanItem.connect('activate', () => {
            this._refreshSinks();
        });
        this._indicator.menu.addMenuItem(rescanItem);

        // Add to GNOME Shell Top Bar
        Main.panel.addToStatusArea(this.uuid, this._indicator);

        // Initial fetch of audio sinks
        this._refreshSinks();
    }

    disable() {
        this._stopDualStream();

        if (this._monitorTimeoutId) {
            GLib.Source.remove(this._monitorTimeoutId);
            this._monitorTimeoutId = 0;
        }

        if (this._indicator) {
            this._indicator.destroy();
            this._indicator = null;
        }

        this._toggleItem = null;
        this._menuSink1 = null;
        this._menuSink2 = null;
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
                    this._updateSinkSubmenus();
                } catch (err) {
                    console.error(`[Dual Audio Hub] Error parsing pw-dump: ${err}`);
                }
            });
        } catch (e) {
            console.error(`[Dual Audio Hub] Error refreshing sinks: ${e}`);
        }
    }

    _updateSinkSubmenus() {
        if (!this._menuSink1 || !this._menuSink2) return;

        this._menuSink1.menu.removeAll();
        this._menuSink2.menu.removeAll();

        if (this._sinks.length === 0) {
            this._menuSink1.menu.addMenuItem(new PopupMenu.PopupMenuItem('No Audio Devices Found', { reactive: false }));
            this._menuSink2.menu.addMenuItem(new PopupMenu.PopupMenuItem('No Audio Devices Found', { reactive: false }));
            return;
        }

        if (!this._targetSink1 && this._sinks.length > 0) this._targetSink1 = this._sinks[0];
        if (!this._targetSink2 && this._sinks.length > 1) this._targetSink2 = this._sinks[1];

        this._sinks.forEach(sink => {
            const prefix1 = (this._targetSink1 && this._targetSink1.name === sink.name) ? '✓ ' : '   ';
            const item1 = new PopupMenu.PopupMenuItem(`${prefix1}${sink.isBluetooth ? '🎧' : '🔈'} ${sink.description}`);
            item1.connect('activate', () => {
                this._targetSink1 = sink;
                this._updateSinkSubmenus();
            });
            this._menuSink1.menu.addMenuItem(item1);

            const prefix2 = (this._targetSink2 && this._targetSink2.name === sink.name) ? '✓ ' : '   ';
            const item2 = new PopupMenu.PopupMenuItem(`${prefix2}${sink.isBluetooth ? '🎧' : '🔈'} ${sink.description}`);
            item2.connect('activate', () => {
                this._targetSink2 = sink;
                this._updateSinkSubmenus();
            });
            this._menuSink2.menu.addMenuItem(item2);
        });

        if (this._targetSink1) {
            this._menuSink1.label.text = `🎧 Device 1: ${this._targetSink1.description}`;
        }
        if (this._targetSink2) {
            this._menuSink2.label.text = `🎧 Device 2: ${this._targetSink2.description}`;
        }
    }

    _startDualStream() {
        if (!this._targetSink1 || !this._targetSink2) {
            Main.notify('Dual Audio Hub', 'Please select two audio devices first.');
            if (this._toggleItem) this._toggleItem.setToggleState(false);
            return;
        }

        this._stopDualStream();

        try {
            // 1. Create Virtual Master Sink (Outputs to Target 1)
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
                // 2. Create Slave Loopback (Captures from Master Sink, Outputs to Target 2)
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
                    // 3. Find Master Sink Node ID & set as default
                    this._setDefaultMasterSink();
                    return GLib.SOURCE_REMOVE;
                });

                return GLib.SOURCE_REMOVE;
            });

            this._isStreaming = true;
            if (this._toggleItem) this._toggleItem.label.text = '⏹ Stop Dual Stream';

            // Start Bluetooth disconnect monitor
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
        if (this._toggleItem) {
            this._toggleItem.setToggleState(false);
            this._toggleItem.label.text = '▶ Start Dual Stream';
        }
    }
}
