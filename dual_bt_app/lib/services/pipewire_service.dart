import 'dart:convert';
import 'dart:io';
import '../models/audio_node.dart';

class PipeWireService {
  final List<Process> _activeLoopbacks = [];
  bool _isStreaming = false;
  int? _originalDefaultSinkId;

  bool get isStreaming => _isStreaming;

  Future<List<AudioSink>> getAudioSinks() async {
    try {
      final result = await Process.run('pw-dump', []);
      if (result.exitCode != 0) return [];

      final List<dynamic> data = jsonDecode(result.stdout as String);
      final List<AudioSink> sinks = [];

      for (final item in data) {
        if (item is Map<String, dynamic> && item['type'] == 'PipeWire:Interface:Node') {
          final props = (item['info'] ?? {})['props'] ?? {};
          final mediaClass = props['media.class'] ?? '';
          final nodeName = props['node.name'] ?? '';
          
          if (mediaClass == 'Audio/Sink' && !nodeName.contains('Dual_Master_Sink')) {
            sinks.add(AudioSink.fromJson(item));
          }
        }
      }
      return sinks;
    } catch (e) {
      print('Error fetching PipeWire sinks: $e');
      return [];
    }
  }

  Future<void> setVolume(AudioSink sink, double volumePercent) async {
    try {
      final double volVal = (volumePercent / 100.0).clamp(0.0, 1.0);
      await Process.run('wpctl', ['set-volume', sink.id.toString(), volVal.toStringAsFixed(2)]);
    } catch (e) {
      print('Error setting volume for sink ${sink.id}: $e');
    }
  }

  Future<double> getVolume(AudioSink sink) async {
    try {
      final res = await Process.run('wpctl', ['get-volume', sink.id.toString()]);
      final String out = (res.stdout as String).trim();
      final match = RegExp(r'Volume:\s*([\d\.]+)').firstMatch(out);
      if (match != null) {
        final double val = double.parse(match.group(1)!);
        return (val * 100.0).clamp(0.0, 100.0);
      }
    } catch (_) {}
    return 100.0;
  }

  Future<int?> _getDefaultSinkId() async {
    try {
      final dump = await Process.run('pw-dump', []);
      final List<dynamic> data = jsonDecode(dump.stdout as String);
      for (final item in data) {
        if (item is Map<String, dynamic> && item['type'] == 'PipeWire:Interface:Node') {
          final props = (item['info'] ?? {})['props'] ?? {};
          if (props['media.class'] == 'Audio/Sink' && item['info']?['state'] == 'running') {
            return item['id'] as int;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fixSlaveStreamLinks() async {
    try {
      final linksResult = await Process.run('pw-link', ['-l']);
      final String linksOutput = linksResult.stdout as String;

      for (final line in linksOutput.split('\n')) {
        if (line.contains('bluez_input') && line.contains('Dual_Slave_Stream')) {
          final parts = line.split('->');
          if (parts.length == 2) {
            final src = parts[0].trim();
            final dst = parts[1].trim();
            await Process.run('pw-link', ['-d', src, dst]);
          }
        }
      }

      await Process.run('pw-link', ['Dual_Master_Sink:monitor_FL', 'input.Dual_Slave_Stream:input_FL']);
      await Process.run('pw-link', ['Dual_Master_Sink:monitor_FR', 'input.Dual_Slave_Stream:input_FR']);
      await Process.run('pw-link', ['Dual_Master_Sink:monitor_FL', 'input.Dual_Slave_Stream:input_MONO']);
    } catch (e) {
      print('Link adjustment note: $e');
    }
  }

  Future<bool> startDualStream({
    required AudioSink target1,
    required AudioSink target2,
    required int delay1Ms,
    required int delay2Ms,
  }) async {
    await stopDualStream();

    try {
      _originalDefaultSinkId = await _getDefaultSinkId() ?? target1.id;

      // 1. Create Virtual Master Sink (Outputs to Target 1)
      final List<String> args1 = [
        '--name', 'Dual_Master_Sink',
        '-i', 'node.name=Dual_Master_Sink media.class=Audio/Sink node.description="Dual Bluetooth Audio Master"',
        '--playback', target1.name,
      ];
      if (delay1Ms > 0) {
        args1.addAll(['--delay', (delay1Ms / 1000.0).toStringAsFixed(3)]);
      }

      final proc1 = await Process.start('pw-loopback', args1);
      _activeLoopbacks.add(proc1);

      await Future.delayed(const Duration(milliseconds: 600));

      // 2. Create Slave Loopback (Captures from Master Sink, Outputs to Target 2)
      final List<String> args2 = [
        '--name', 'Dual_Slave_Stream',
        '--capture', 'Dual_Master_Sink',
        '--playback', target2.name,
      ];
      if (delay2Ms > 0) {
        args2.addAll(['--delay', (delay2Ms / 1000.0).toStringAsFixed(3)]);
      }

      final proc2 = await Process.start('pw-loopback', args2);
      _activeLoopbacks.add(proc2);

      await Future.delayed(const Duration(milliseconds: 600));

      await _fixSlaveStreamLinks();

      // 3. Find Master Sink Node ID & set as default sink in PipeWire
      final dump = await Process.run('pw-dump', []);
      final List<dynamic> data = jsonDecode(dump.stdout as String);
      int? masterNodeId;
      for (final item in data) {
        if (item is Map<String, dynamic> && item['type'] == 'PipeWire:Interface:Node') {
          final props = (item['info'] ?? {})['props'] ?? {};
          if (props['node.name'] == 'Dual_Master_Sink') {
            masterNodeId = item['id'] as int;
            break;
          }
        }
      }

      if (masterNodeId != null) {
        await Process.run('wpctl', ['set-default', masterNodeId.toString()]);
      }

      _isStreaming = true;
      return true;
    } catch (e) {
      print('Error starting dual stream: $e');
      await stopDualStream();
      return false;
    }
  }

  Future<void> stopDualStream() async {
    if (_originalDefaultSinkId != null) {
      try {
        await Process.run('wpctl', ['set-default', _originalDefaultSinkId!.toString()]);
      } catch (_) {}
    }

    for (final proc in _activeLoopbacks) {
      try {
        proc.kill(ProcessSignal.sigterm);
      } catch (_) {}
    }
    _activeLoopbacks.clear();
    _isStreaming = false;
  }
}
