/*
 * Dual Audio Hub - GNOME Quick Settings Extension
 * Native GNOME 45+ Quick Settings Integration
 * https://extensions.gnome.org/
 */

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';

// Custom GNOME Quick Settings Toggle Class
const DualAudioToggle = GObject.registerClass(
class DualAudioToggle extends QuickSettings.QuickMenuToggle {
    _init() {
        super._init({
            title: 'Dual Audio',
            subtitle: 'Off',
            iconName: 'audio-headphones-symbolic',
            toggleMode: true,
        });

        // Header inside the Quick Settings expanded submenu
        this.menu.setHeader('audio-headphones-symbolic', 'Dual Audio Hub', 'PipeWire Dual Bluetooth Streamer');

        // Submenus for Device Selection
        this.itemDevice1 = new PopupMenu.PopupSubMenuMenuItem('🎧 Device 1 (Primary Output)');
        this.itemDevice2 = new PopupMenu.PopupSubMenuMenuItem('🎧 Device 2 (Secondary Output)');

        this.menu.addMenuItem(this.itemDevice1);
        this.menu.addMenuItem(this.itemDevice2);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Rescan button inside menu
        const rescanItem = new PopupMenu.PopupMenuItem('🔄 Rescan Audio Devices');
        rescanItem.connect('activate', () => {
            if (this._extension) {
                this._extension._refreshSinks();
            }
        });
        this.menu.addMenuItem(rescanItem);
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

        // Create Quick Settings Toggle
        this._toggle = new DualAudioToggle();
        this._toggle._extension = this;

        // Handle Main Toggle Switch click
        this._toggle.connect('clicked', () => {
            if (this._toggle.checked) {
                this._startDualStream();
            } else {
                this._stopDualStream();
            }
        });

        // Add directly into GNOME Shell Quick Settings Menu!
        Main.panel.statusArea.quickSettings.addExternalToggle(this._toggle);

        // Fetch PipeWire sinks
        this._refreshSinks();
    }

    disable() {
        this._stopDualStream();

        if (this._monitorTimeoutId) {
            GLib.Source.remove(this._monitorTimeoutId);
            this._monitorTimeoutId = 0;
        }

        if (this._toggle) {
            this._toggle.destroy();
            this._toggle = null;
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
        if (!this._toggle) return;

        const m1 = this._toggle.itemDevice1;
        const m2 = this._toggle.itemDevice2;

        if (!m1 || !m2) return;

        m1.menu.removeAll();
        m2.menu.removeAll();

        if (this._sinks.length === 0) {
            m1.menu.addMenuItem(new PopupMenu.PopupMenuItem('No Audio Devices Found', { reactive: false }));
            m2.menu.addMenuItem(new PopupMenu.PopupMenuItem('No Audio Devices Found', { reactive: false }));
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
            m1.menu.addMenuItem(item1);

            const prefix2 = (this._targetSink2 && this._targetSink2.name === sink.name) ? '✓ ' : '   ';
            const item2 = new PopupMenu.PopupMenuItem(`${prefix2}${sink.isBluetooth ? '🎧' : '🔈'} ${sink.description}`);
            item2.connect('activate', () => {
                this._targetSink2 = sink;
                this._updateSinkSubmenus();
            });
            m2.menu.addMenuItem(item2);
        });

        if (this._targetSink1) {
            m1.label.text = `🎧 Device 1: ${this._targetSink1.description}`;
        }
        if (this._targetSink2) {
            m2.label.text = `🎧 Device 2: ${this._targetSink2.description}`;
        }

        if (this._isStreaming && this._targetSink1 && this._targetSink2) {
            this._toggle.subtitle = `${this._targetSink1.description} + ${this._targetSink2.description}`;
        } else {
            this._toggle.subtitle = 'Off';
        }
    }

    _startDualStream() {
        if (!this._targetSink1 || !this._targetSink2) {
            Main.notify('Dual Audio Hub', 'Please select two audio devices first.');
            if (this._toggle) this._toggle.checked = false;
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
            if (this._toggle) {
                this._toggle.checked = true;
                this._toggle.subtitle = 'Streaming Dual Audio';
            }

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
        if (this._toggle) {
            this._toggle.checked = false;
            this._toggle.subtitle = 'Off';
        }
    }
}
