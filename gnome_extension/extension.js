/**
 * Dual Audio Hub - GNOME Shell Extension
 *
 * Provides a Quick Settings menu toggle to stream synchronized audio
 * to two Bluetooth audio sinks (or any two audio output sinks) simultaneously
 * using PipeWire loopback nodes.
 *
 * @author Pardhu
 * @license GPL-3.0-or-later
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

/**
 * Custom PopupMenu slider widget for per-device volume control.
 */
const VolumeSliderItem = GObject.registerClass(
class VolumeSliderItem extends PopupMenu.PopupBaseMenuItem {
    _init(deviceTitle) {
        super._init({ activate: false });
        this._signalIds = [];

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

        const id = this._slider.connect('notify::value', () => {
            const percentage = Math.round(this._slider.value * 100);
            this._label.text = `${percentage}%`;
        });
        this._signalIds.push({ object: this._slider, id });
    }

    get slider() {
        return this._slider;
    }

    get value() {
        return this._slider.value;
    }

    set value(val) {
        const clampedVal = Math.max(0.0, Math.min(1.0, val));
        this._slider.value = clampedVal;
        this._label.text = `${Math.round(clampedVal * 100)}%`;
    }

    destroy() {
        for (const { object, id } of this._signalIds) {
            if (object && id) {
                object.disconnect(id);
            }
        }
        this._signalIds = [];
        super.destroy();
    }
});

/**
 * Quick Settings toggle switch and submenu container.
 */
const DualAudioToggle = GObject.registerClass(
class DualAudioToggle extends QuickSettings.QuickMenuToggle {
    _init(extension) {
        super._init({
            title: 'Dual Audio',
            subtitle: 'Off',
            iconName: 'audio-headphones-symbolic',
            toggleMode: true,
        });

        this._extension = extension;
        this._menuSignalIds = [];

        this.menu.setHeader('audio-headphones-symbolic', 'Dual Audio Hub', 'Dual Audio Streaming');

        const openId = this.menu.connect('open-state-changed', (menu, isOpen) => {
            if (isOpen && this._extension) {
                this._extension.refreshSinks();
            }
        });
        this._menuSignalIds.push({ object: this.menu, id: openId });

        this._statusItem = new PopupMenu.PopupMenuItem('', { reactive: false });
        this._statusItem.label.style = 'font-style: italic; color: #888;';
        this.menu.addMenuItem(this._statusItem);
        this._statusItem.visible = false;

        this.itemDevice1 = new PopupMenu.PopupSubMenuMenuItem('🎧 Device 1: Select');
        this.menu.addMenuItem(this.itemDevice1);

        this.volSlider1 = new VolumeSliderItem('Device 1');
        this.menu.addMenuItem(this.volSlider1);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        this.itemDevice2 = new PopupMenu.PopupSubMenuMenuItem('🎧 Device 2: Select');
        this.menu.addMenuItem(this.itemDevice2);

        this.volSlider2 = new VolumeSliderItem('Device 2');
        this.menu.addMenuItem(this.volSlider2);

        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());

        const refreshItem = new PopupMenu.PopupMenuItem('↻  Refresh Devices');
        const refreshId = refreshItem.connect('activate', () => {
            if (this._extension) {
                this._extension.refreshSinks();
            }
        });
        this._menuSignalIds.push({ object: refreshItem, id: refreshId });
        this.menu.addMenuItem(refreshItem);
    }

    setStatus(text) {
        if (!text) {
            this._statusItem.visible = false;
        } else {
            this._statusItem.label.text = text;
            this._statusItem.visible = true;
        }
    }

    destroy() {
        for (const { object, id } of this._menuSignalIds) {
            if (object && id) {
                object.disconnect(id);
            }
        }
        this._menuSignalIds = [];
        this._extension = null;
        super.destroy();
    }
});

/**
 * System status bar indicator.
 */
const DualAudioIndicator = GObject.registerClass(
class DualAudioIndicator extends QuickSettings.SystemIndicator {
    _init(extension) {
        super._init();

        this._indicator = this._addIndicator();
        this._indicator.icon_name = 'audio-headphones-symbolic';
        this._indicator.visible = false;

        this._toggle = new DualAudioToggle(extension);
        this.quickSettingsItems.push(this._toggle);
    }

    get toggle() {
        return this._toggle;
    }

    destroy() {
        this.quickSettingsItems.forEach(item => item.destroy());
        super.destroy();
    }
});

/**
 * Main extension lifecycle manager.
 */
export default class DualAudioExtension extends Extension {
    enable() {
        this._isStreaming = false;
        this._startingStream = false;
        this._sinks = [];
        this._targetSink1 = null;
        this._targetSink2 = null;

        this._activeSubprocesses = [];
        this._pendingTimeouts = [];
        this._signalIds = [];

        this._volDebounce1 = 0;
        this._volDebounce2 = 0;

        this._systemIndicator = new DualAudioIndicator(this);
        const toggle = this._systemIndicator.toggle;

        const toggleId = toggle.connect('clicked', () => {
            if (toggle.checked) {
                this._startDualStream();
            } else {
                this._stopDualStream();
            }
        });
        this._signalIds.push({ object: toggle, id: toggleId });

        const vol1Id = toggle.volSlider1.slider.connect('notify::value', () => {
            this._debounceVolumeChange(1, toggle.volSlider1.value);
        });
        this._signalIds.push({ object: toggle.volSlider1.slider, id: vol1Id });

        const vol2Id = toggle.volSlider2.slider.connect('notify::value', () => {
            this._debounceVolumeChange(2, toggle.volSlider2.value);
        });
        this._signalIds.push({ object: toggle.volSlider2.slider, id: vol2Id });

        Main.panel.statusArea.quickSettings.addExternalIndicator(this._systemIndicator);

        this.refreshSinks();
    }

    disable() {
        this._stopDualStream();
        this._clearAllTimeouts();

        for (const { object, id } of this._signalIds) {
            if (object && id) {
                object.disconnect(id);
            }
        }
        this._signalIds = [];

        if (this._systemIndicator) {
            this._systemIndicator.destroy();
            this._systemIndicator = null;
        }

        this._sinks = [];
        this._targetSink1 = null;
        this._targetSink2 = null;
    }

    _debounceVolumeChange(deviceIndex, volumeValue) {
        const debounceKey = deviceIndex === 1 ? '_volDebounce1' : '_volDebounce2';

        if (this[debounceKey]) {
            GLib.Source.remove(this[debounceKey]);
            this[debounceKey] = 0;
        }

        this[debounceKey] = GLib.timeout_add(GLib.PRIORITY_DEFAULT, 50, () => {
            this[debounceKey] = 0;
            const targetSink = deviceIndex === 1 ? this._targetSink1 : this._targetSink2;
            if (targetSink) {
                this._setVolume(targetSink.id, volumeValue);
            }
            return GLib.SOURCE_REMOVE;
        });
    }

    _clearAllTimeouts() {
        if (this._volDebounce1) {
            GLib.Source.remove(this._volDebounce1);
            this._volDebounce1 = 0;
        }
        if (this._volDebounce2) {
            GLib.Source.remove(this._volDebounce2);
            this._volDebounce2 = 0;
        }
        for (const tid of this._pendingTimeouts) {
            if (tid) {
                GLib.Source.remove(tid);
            }
        }
        this._pendingTimeouts = [];
    }

    _addTimeout(delayMs, callback) {
        const tid = GLib.timeout_add(GLib.PRIORITY_DEFAULT, delayMs, () => {
            this._removeTimeout(tid);
            callback();
            return GLib.SOURCE_REMOVE;
        });
        this._pendingTimeouts.push(tid);
        return tid;
    }

    _removeTimeout(tid) {
        const idx = this._pendingTimeouts.indexOf(tid);
        if (idx !== -1) {
            this._pendingTimeouts.splice(idx, 1);
        }
    }

    _setVolume(sinkId, volume) {
        const volumeArg = volume.toFixed(2);
        try {
            Gio.Subprocess.new(
                ['wpctl', 'set-volume', String(sinkId), volumeArg],
                Gio.SubprocessFlags.NONE
            );
        } catch (err) {
            console.warn(`[Dual Audio Hub] Failed to set volume for sink ${sinkId}: ${err.message}`);
        }
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
                        if (match) {
                            callback(parseFloat(match[1]));
                        }
                    }
                } catch (err) {
                    console.warn(`[Dual Audio Hub] Failed to read volume output: ${err.message}`);
                }
            });
        } catch (err) {
            console.warn(`[Dual Audio Hub] Failed to execute wpctl get-volume: ${err.message}`);
        }
    }

    _ensureA2dpProfile(sink) {
        if (!sink || !sink.deviceId) return;
        try {
            Gio.Subprocess.new(
                ['wpctl', 'set-profile', String(sink.deviceId), 'a2dp-sink-sbc'],
                Gio.SubprocessFlags.NONE
            );
        } catch (_) {}
    }

    refreshSinks() {
        try {
            const proc = Gio.Subprocess.new(
                ['pw-dump'],
                Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENT
            );

            proc.communicate_utf8_async(null, null, (obj, res) => {
                try {
                    const [, stdout] = obj.communicate_utf8_finish(res);
                    if (!stdout) {
                        this._setStatusMessage('PipeWire not responding');
                        return;
                    }

                    const data = JSON.parse(stdout);
                    const parsedSinks = [];

                    for (const item of data) {
                        if (item && item.type === 'PipeWire:Interface:Node') {
                            const props = (item.info && item.info.props) || {};
                            const mediaClass = props['media.class'] || '';
                            const nodeName = props['node.name'] || '';
                            const factory = props['factory.name'] || '';
                            const api = props['device.api'] || '';

                            if (mediaClass.startsWith('Audio/Sink') && !nodeName.includes('Dual_Master_Sink')) {
                                const isBt = nodeName.includes('bluez') || factory.includes('bluez') || api === 'bluez5';
                                const desc = props['node.description'] || props['media.name'] || nodeName;
                                parsedSinks.push({
                                    id: item.id,
                                    deviceId: props['device.id'] || null,
                                    name: nodeName,
                                    description: desc,
                                    isBluetooth: isBt,
                                });
                            }
                        }
                    }

                    // Sort Bluetooth sinks first
                    parsedSinks.sort((a, b) => (b.isBluetooth ? 1 : 0) - (a.isBluetooth ? 1 : 0));

                    this._sinks = parsedSinks;

                    if (this._targetSink1 && !this._sinks.find(s => s.name === this._targetSink1.name)) {
                        this._targetSink1 = null;
                    }
                    if (this._targetSink2 && !this._sinks.find(s => s.name === this._targetSink2.name)) {
                        this._targetSink2 = null;
                    }

                    const btSinks = this._sinks.filter(s => s.isBluetooth);
                    if (!this._targetSink1) {
                        this._targetSink1 = btSinks.length > 0 ? btSinks[0] : (this._sinks[0] || null);
                    }
                    if (!this._targetSink2) {
                        this._targetSink2 = btSinks.length > 1 ? btSinks[1] : (this._sinks.find(s => s.name !== (this._targetSink1 && this._targetSink1.name)) || null);
                    }

                    if (this._targetSink1 && this._targetSink2 && this._targetSink1.name === this._targetSink2.name) {
                        const altSink = this._sinks.find(s => s.name !== this._targetSink1.name);
                        if (altSink) {
                            this._targetSink2 = altSink;
                        }
                    }

                    if (this._sinks.length === 0) {
                        this._setStatusMessage('No audio devices found');
                    } else if (btSinks.length === 0) {
                        this._setStatusMessage('No Bluetooth devices connected');
                    } else if (btSinks.length === 1) {
                        this._setStatusMessage('Connect 1 more Bluetooth device');
                    } else {
                        this._setStatusMessage(null);
                    }

                    this._updateSinkSubmenus();
                    this._syncVolumeSliders();
                } catch (err) {
                    console.error(`[Dual Audio Hub] Error parsing pw-dump output: ${err}`);
                    this._setStatusMessage('Error reading audio devices');
                }
            });
        } catch (err) {
            console.error(`[Dual Audio Hub] Failed to execute pw-dump: ${err}`);
            this._setStatusMessage('PipeWire tools not found');
        }
    }

    _setStatusMessage(msg) {
        if (this._systemIndicator && this._systemIndicator.toggle) {
            this._systemIndicator.toggle.setStatus(msg);
        }
    }

    _syncVolumeSliders() {
        const toggle = this._systemIndicator && this._systemIndicator.toggle;
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
        const toggle = this._systemIndicator && this._systemIndicator.toggle;
        if (!toggle || !toggle.itemDevice1 || !toggle.itemDevice2) return;

        const m1 = toggle.itemDevice1.menu;
        const m2 = toggle.itemDevice2.menu;
        m1.removeAll();
        m2.removeAll();

        if (this._sinks.length === 0) {
            m1.addMenuItem(new PopupMenu.PopupMenuItem('No audio devices found', { reactive: false }));
            m2.addMenuItem(new PopupMenu.PopupMenuItem('No audio devices found', { reactive: false }));
            toggle.itemDevice1.label.text = '🎧 Device 1: Select';
            toggle.itemDevice2.label.text = '🎧 Device 2: Select';
        } else {
            this._sinks.forEach(sink => {
                const iconPrefix = sink.isBluetooth ? '🎧 ' : '🔊 ';
                const check1 = (this._targetSink1 && this._targetSink1.name === sink.name) ? '✓ ' : '   ';
                const item1 = new PopupMenu.PopupMenuItem(`${check1}${iconPrefix}${sink.description}`);
                item1.connect('activate', () => {
                    if (this._targetSink2 && this._targetSink2.name === sink.name) {
                        Main.notify('Dual Audio Hub', 'This device is already selected as Device 2.');
                        return;
                    }
                    this._targetSink1 = sink;
                    this._updateSinkSubmenus();
                    this._syncVolumeSliders();
                    if (this._isStreaming) {
                        this._restartStream();
                    }
                });
                m1.addMenuItem(item1);

                const check2 = (this._targetSink2 && this._targetSink2.name === sink.name) ? '✓ ' : '   ';
                const item2 = new PopupMenu.PopupMenuItem(`${check2}${iconPrefix}${sink.description}`);
                item2.connect('activate', () => {
                    if (this._targetSink1 && this._targetSink1.name === sink.name) {
                        Main.notify('Dual Audio Hub', 'This device is already selected as Device 1.');
                        return;
                    }
                    this._targetSink2 = sink;
                    this._updateSinkSubmenus();
                    this._syncVolumeSliders();
                    if (this._isStreaming) {
                        this._restartStream();
                    }
                });
                m2.addMenuItem(item2);
            });

            if (this._targetSink1) {
                const icon = this._targetSink1.isBluetooth ? '🎧' : '🔊';
                toggle.itemDevice1.label.text = `${icon} Device 1: ${this._targetSink1.description}`;
            } else {
                toggle.itemDevice1.label.text = '🎧 Device 1: Select';
            }

            if (this._targetSink2) {
                const icon = this._targetSink2.isBluetooth ? '🎧' : '🔊';
                toggle.itemDevice2.label.text = `${icon} Device 2: ${this._targetSink2.description}`;
            } else {
                toggle.itemDevice2.label.text = '🎧 Device 2: Select';
            }
        }

        toggle.subtitle = this._isStreaming ? 'Streaming' : 'Off';
    }

    _restartStream() {
        if (!this._isStreaming) return;
        this._stopDualStream();
        this._addTimeout(300, () => {
            this._startDualStream();
        });
    }

    _startDualStream() {
        if (this._startingStream) return;

        if (!this._targetSink1 || !this._targetSink2) {
            const msg = this._sinks.length < 2
                ? 'Connect at least two audio devices first.'
                : 'Select two different audio devices first.';
            Main.notify('Dual Audio Hub', msg);
            if (this._systemIndicator && this._systemIndicator.toggle) {
                this._systemIndicator.toggle.checked = false;
            }
            return;
        }

        if (this._targetSink1.name === this._targetSink2.name) {
            Main.notify('Dual Audio Hub', 'Device 1 and Device 2 must be different.');
            if (this._systemIndicator && this._systemIndicator.toggle) {
                this._systemIndicator.toggle.checked = false;
            }
            return;
        }

        this._startingStream = true;
        this._stopDualStream();

        try {
            const proc1 = Gio.Subprocess.new(
                [
                    'pw-loopback',
                    '--name', 'Dual_Master_Sink',
                    '-i', 'node.name=Dual_Master_Sink media.class=Audio/Sink node.description="Dual Master" node.latency=2048/48000',
                    '--playback', this._targetSink1.name,
                ],
                Gio.SubprocessFlags.NONE
            );
            this._activeSubprocesses.push(proc1);

            this._addTimeout(500, () => {
                if (!this._startingStream) return;

                try {
                    const proc2 = Gio.Subprocess.new(
                        [
                            'pw-loopback',
                            '--name', 'Dual_Slave_Stream',
                            '-i', 'stream.capture.sink=true node.latency=2048/48000',
                            '--capture', 'Dual_Master_Sink',
                            '--playback', this._targetSink2.name,
                        ],
                        Gio.SubprocessFlags.NONE
                    );
                    this._activeSubprocesses.push(proc2);

                    this._addTimeout(500, () => {
                        this._setDefaultMasterSink();
                        this._startingStream = false;
                    });
                } catch (err) {
                    console.error(`[Dual Audio Hub] Error starting slave stream: ${err}`);
                    this._startingStream = false;
                    this._stopDualStream();
                    Main.notify('Dual Audio Hub', 'Failed to start audio stream.');
                }
            });

            this._isStreaming = true;
            if (this._systemIndicator) {
                this._systemIndicator.toggle.checked = true;
                this._systemIndicator.toggle.subtitle = 'Streaming';
                this._systemIndicator.toggle._indicator.visible = true;
            }

            Main.notify('Dual Audio Hub', `Streaming to ${this._targetSink1.description} & ${this._targetSink2.description} 🎧🎧`);
        } catch (err) {
            console.error(`[Dual Audio Hub] Error starting stream: ${err}`);
            this._startingStream = false;
            this._stopDualStream();
            Main.notify('Dual Audio Hub', 'Failed to start dual audio stream.');
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
                } catch (err) {
                    console.warn(`[Dual Audio Hub] Error finding default master sink: ${err.message}`);
                }
            });
        } catch (err) {
            console.warn(`[Dual Audio Hub] Failed pw-dump execution: ${err.message}`);
        }
    }

    _stopDualStream() {
        for (const proc of this._activeSubprocesses) {
            try {
                proc.force_exit();
            } catch (err) {
                console.warn(`[Dual Audio Hub] Process exit warning: ${err.message}`);
            }
        }
        this._activeSubprocesses = [];

        this._isStreaming = false;
        this._startingStream = false;

        if (this._systemIndicator) {
            this._systemIndicator.toggle.checked = false;
            this._systemIndicator.toggle.subtitle = 'Off';
            this._systemIndicator.toggle._indicator.visible = false;
        }
    }
}
