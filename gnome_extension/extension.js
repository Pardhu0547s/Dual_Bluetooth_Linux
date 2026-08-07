/*
 * Dual Audio Hub - GNOME Shell Extension
 * Compatible with GNOME 45, 46, 47, 48, 49, 50, 51
 * Uses SystemIndicator + QuickMenuToggle for proper Quick Settings grid integration
 */

import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as QuickSettings from 'resource:///org/gnome/shell/ui/quickSettings.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import * as Slider from 'resource:///org/gnome/shell/ui/slider.js';
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Clutter from 'gi://Clutter';

// Volume slider menu item
const VolumeSliderItem = GObject.registerClass(
class VolumeSliderItem extends PopupMenu.PopupBaseMenuItem {
    _init(label) {
        super._init({ activate: false });

        this._icon = new St.Icon({
            icon_name: 'audio-volume-high-symbolic',
            style_class: 'popup-menu-icon',
        });
        this.add_child(this._icon);

        this._slider = new Slider.Slider(1.0);
        this._slider.x_expand = true;
        this.add_child(this._slider);

        this._label = new St.Label({
            text: '100%',
            y_align: Clutter.ActorAlign.CENTER,
            style: 'min-width: 42px; text-align: right;',
        });
        this.add_child(this._label);

        this._slider.connect('notify::value', () => {
            const pct = Math.round(this._slider.value * 100);
            this._label.text = `${pct}%`;
        });
    }

    get slider() { return this._slider; }
    get value() { return this._slider.value; }
    set value(v) {
        this._slider.value = v;
        this._label.text = `${Math.round(v * 100)}%`;
    }
});

// Quick Settings Toggle that appears in the grid alongside Wi-Fi, Bluetooth, etc.
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
            this.menu.setHeader('audio-headphones-symbolic', 'Dual Audio Hub', 'Dual Bluetooth Stream');
        } catch (_) {}

        // Device 1 (Primary) submenu
        this.itemDevice1 = new PopupMenu.PopupSubMenuMenuItem('🎧 Device 1: Select');
        this.menu.addMenuItem(this.itemDevice1);

        // Volume slider for Device 1
        this.volSlider1 = new VolumeSliderItem('Vol 1');
        this.menu.addMenuItem(this.volSlider1);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Device 2 (Secondary) submenu
        this.itemDevice2 = new PopupMenu.PopupSubMenuMenuItem('🎧 Device 2: Select');
        this.menu.addMenuItem(this.itemDevice2);

        // Volume slider for Device 2
        this.volSlider2 = new VolumeSliderItem('Vol 2');
        this.menu.addMenuItem(this.volSlider2);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        // Refresh button
        const refreshItem = new PopupMenu.PopupMenuItem('↻  Refresh Devices');
        refreshItem.connect('activate', () => {
            if (this._extensionRef) {
                this._extensionRef._refreshSinks();
            }
        });
        this.menu.addMenuItem(refreshItem);
    }
});

// SystemIndicator - the proper way to register into the Quick Settings grid
const DualAudioIndicator = GObject.registerClass(
class DualAudioIndicator extends QuickSettings.SystemIndicator {
    constructor(extensionObject) {
        super();

        this._indicator = this._addIndicator();
        this._indicator.icon_name = 'audio-headphones-symbolic';
        this._indicator.visible = false;

        this._toggle = new DualAudioToggle();
        this._toggle._extensionObj = extensionObject;

        this.quickSettingsItems.push(this._toggle);
    }

    destroy() {
        this.quickSettingsItems.forEach(item => item.destroy());
        super.destroy();
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

        this._systemIndicator = new DualAudioIndicator(this);
        this._systemIndicator._toggle._extensionRef = this;

        this._systemIndicator._toggle.connect('clicked', () => {
            if (this._systemIndicator._toggle.checked) {
                this._startDualStream();
            } else {
                this._stopDualStream();
            }
        });

        // Wire up volume sliders
        const toggle = this._systemIndicator._toggle;
        toggle.volSlider1.slider.connect('notify::value', () => {
            if (this._targetSink1) {
                this._setVolume(this._targetSink1.id, toggle.volSlider1.value);
            }
        });
        toggle.volSlider2.slider.connect('notify::value', () => {
            if (this._targetSink2) {
                this._setVolume(this._targetSink2.id, toggle.volSlider2.value);
            }
        });

        Main.panel.statusArea.quickSettings.addExternalIndicator(this._systemIndicator);

        this._refreshSinks();
    }

    disable() {
        this._stopDualStream();

        if (this._monitorTimeoutId) {
            GLib.Source.remove(this._monitorTimeoutId);
            this._monitorTimeoutId = 0;
        }

        if (this._systemIndicator) {
            this._systemIndicator.destroy();
            this._systemIndicator = null;
        }
    }

    _setVolume(sinkId, volume) {
        try {
            Gio.Subprocess.new(
                ['wpctl', 'set-volume', String(sinkId), String(volume.toFixed(2))],
                Gio.SubprocessFlags.NONE
            );
        } catch (_) {}
    }

    _getVolume(sinkId, callback) {
        try {
            const proc = Gio.Subprocess.new(
                ['wpctl', 'get-volume', String(sinkId)],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENT
            );
            proc.communicate_utf8_async(null, null, (obj, res) => {
                try {
                    const [, stdout] = obj.communicate_utf8_finish(res);
                    if (stdout) {
                        const match = stdout.match(/Volume:\s*([\d.]+)/);
                        if (match) callback(parseFloat(match[1]));
                    }
                } catch (_) {}
            });
        } catch (_) {}
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

                            // Only show Bluetooth audio sinks
                            const isBt = nodeName.includes('bluez') || props['device.api'] === 'bluez5';
                            if (mediaClass === 'Audio/Sink' && isBt && !nodeName.includes('Dual_Master_Sink')) {
                                const desc = props['node.description'] || nodeName;
                                parsedSinks.push({
                                    id: item.id,
                                    name: nodeName,
                                    description: desc,
                                    isBluetooth: true,
                                });
                            }
                        }
                    }

                    this._sinks = parsedSinks;
                    if (this._sinks.length > 0 && !this._targetSink1) this._targetSink1 = this._sinks[0];
                    if (this._sinks.length > 1 && !this._targetSink2) this._targetSink2 = this._sinks[1];
                    this._updateSinkSubmenus();
                    this._syncVolumeSliders();
                } catch (err) {
                    console.error(`[Dual Audio Hub] Error parsing pw-dump: ${err}`);
                }
            });
        } catch (e) {
            console.error(`[Dual Audio Hub] Error refreshing sinks: ${e}`);
        }
    }

    _syncVolumeSliders() {
        const toggle = this._systemIndicator && this._systemIndicator._toggle;
        if (!toggle) return;

        if (this._targetSink1) {
            this._getVolume(this._targetSink1.id, (vol) => {
                toggle.volSlider1.value = Math.min(vol, 1.0);
            });
        }
        if (this._targetSink2) {
            this._getVolume(this._targetSink2.id, (vol) => {
                toggle.volSlider2.value = Math.min(vol, 1.0);
            });
        }
    }

    _updateSinkSubmenus() {
        const toggle = this._systemIndicator && this._systemIndicator._toggle;
        if (!toggle || !toggle.itemDevice1 || !toggle.itemDevice2) return;

        try {
            const m1 = toggle.itemDevice1.menu;
            const m2 = toggle.itemDevice2.menu;
            m1.removeAll();
            m2.removeAll();

            if (this._sinks.length === 0) {
                m1.addMenuItem(new PopupMenu.PopupMenuItem('No Bluetooth devices', { reactive: false }));
                m2.addMenuItem(new PopupMenu.PopupMenuItem('No Bluetooth devices', { reactive: false }));
            } else {
                this._sinks.forEach(sink => {
                    const check1 = (this._targetSink1 && this._targetSink1.name === sink.name) ? '✓ ' : '   ';
                    const it1 = new PopupMenu.PopupMenuItem(`${check1}🎧 ${sink.description}`);
                    it1.connect('activate', () => {
                        this._targetSink1 = sink;
                        this._updateSinkSubmenus();
                        this._syncVolumeSliders();
                    });
                    m1.addMenuItem(it1);

                    const check2 = (this._targetSink2 && this._targetSink2.name === sink.name) ? '✓ ' : '   ';
                    const it2 = new PopupMenu.PopupMenuItem(`${check2}🎧 ${sink.description}`);
                    it2.connect('activate', () => {
                        this._targetSink2 = sink;
                        this._updateSinkSubmenus();
                        this._syncVolumeSliders();
                    });
                    m2.addMenuItem(it2);
                });
            }

            if (this._targetSink1) toggle.itemDevice1.label.text = `🎧 Device 1: ${this._targetSink1.description}`;
            if (this._targetSink2) toggle.itemDevice2.label.text = `🎧 Device 2: ${this._targetSink2.description}`;

            toggle.subtitle = this._isStreaming ? 'Streaming' : 'Off';
        } catch (e) {
            console.error(`[Dual Audio Hub] Error updating submenus: ${e}`);
        }
    }

    _startDualStream() {
        if (!this._targetSink1 || !this._targetSink2) {
            Main.notify('Dual Audio Hub', 'Connect at least two Bluetooth devices first.');
            if (this._systemIndicator && this._systemIndicator._toggle) {
                this._systemIndicator._toggle.checked = false;
            }
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
            if (this._systemIndicator) {
                this._systemIndicator._toggle.checked = true;
                this._systemIndicator._toggle.subtitle = 'Streaming';
                this._systemIndicator._indicator.visible = true;
            }

            this._startDisconnectMonitor();
            Main.notify('Dual Audio Hub', 'Dual Bluetooth streaming active! 🎧🎧');
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
                        Main.notify('Dual Audio Hub', `${gone} disconnected. Stopped dual stream.`);
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
        if (this._systemIndicator) {
            this._systemIndicator._toggle.checked = false;
            this._systemIndicator._toggle.subtitle = 'Off';
            this._systemIndicator._indicator.visible = false;
        }
    }
}
