import 'dart:async';
import 'package:flutter/services.dart';
import '../models/audio_node.dart';
import 'audio_service.dart';

/// Windows audio service using WASAPI loopback capture and dual render.
/// Communicates with native C++ code via MethodChannel.
class WindowsAudioService extends AudioService {
  static const _channel = MethodChannel('com.dualbt.audio');
  bool _isStreaming = false;

  @override
  Function(String deviceName)? onDeviceDisconnected;

  @override
  bool get isStreaming => _isStreaming;

  @override
  String get platformName => 'Windows (WASAPI)';

  @override
  bool get supportsDualAudio => true;

  @override
  Future<List<AudioSink>> getAudioSinks() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getAudioSinks');
      return result.map((item) {
        final map = Map<String, dynamic>.from(item);
        return AudioSink(
          id: map['id'] as int,
          name: map['name'] as String,
          description: map['description'] as String,
          isBluetooth: map['isBluetooth'] as bool,
        );
      }).toList();
    } catch (e) {
      print('Windows getAudioSinks error: $e');
      return [];
    }
  }

  @override
  Future<bool> startDualStream({
    required AudioSink target1,
    required AudioSink target2,
  }) async {
    try {
      final bool success = await _channel.invokeMethod('startDualStream', {
        'sink1Name': target1.name,
        'sink2Name': target2.name,
      });
      _isStreaming = success;
      if (success) {
        _startDisconnectMonitor(target1, target2);
      }
      return success;
    } catch (e) {
      print('Windows startDualStream error: $e');
      return false;
    }
  }

  @override
  Future<void> stopDualStream() async {
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    try {
      await _channel.invokeMethod('stopDualStream');
    } catch (e) {
      print('Windows stopDualStream error: $e');
    }
    _isStreaming = false;
  }

  @override
  Future<void> setVolume(AudioSink sink, double volumePercent) async {
    try {
      await _channel.invokeMethod('setVolume', {
        'sinkId': sink.id,
        'volume': (volumePercent / 100.0).clamp(0.0, 1.0),
      });
    } catch (e) {
      print('Windows setVolume error: $e');
    }
  }

  @override
  Future<double> getVolume(AudioSink sink) async {
    try {
      final double vol = await _channel.invokeMethod('getVolume', {
        'sinkId': sink.id,
      });
      return (vol * 100.0).clamp(0.0, 100.0);
    } catch (e) {
      print('Windows getVolume error: $e');
      return 100.0;
    }
  }

  Timer? _disconnectTimer;

  void _startDisconnectMonitor(AudioSink target1, AudioSink target2) {
    _disconnectTimer?.cancel();
    _disconnectTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_isStreaming) return;
      final sinks = await getAudioSinks();
      final names = sinks.map((s) => s.name).toSet();

      if (!names.contains(target1.name) || !names.contains(target2.name)) {
        final gone = !names.contains(target1.name) ? target1.description : target2.description;
        await stopDualStream();
        onDeviceDisconnected?.call(gone);
      }
    });
  }
}
