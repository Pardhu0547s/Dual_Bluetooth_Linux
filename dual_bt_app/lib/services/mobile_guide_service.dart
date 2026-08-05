import 'dart:async';
import '../models/audio_node.dart';
import 'audio_service.dart';

/// Stub audio service for Android and iOS.
/// These platforms do not support programmatic dual Bluetooth audio routing.
/// This service returns empty results and signals that the user should use
/// built-in OS features (Samsung Dual Audio, Apple Audio Sharing, etc.).
class MobileGuideService extends AudioService {
  @override
  Function(String deviceName)? onDeviceDisconnected;

  @override
  bool get isStreaming => false;

  @override
  String get platformName => 'Mobile';

  @override
  bool get supportsDualAudio => false;

  @override
  Future<List<AudioSink>> getAudioSinks() async => [];

  @override
  Future<bool> startDualStream({
    required AudioSink target1,
    required AudioSink target2,
  }) async => false;

  @override
  Future<void> stopDualStream() async {}

  @override
  Future<void> setVolume(AudioSink sink, double volumePercent) async {}

  @override
  Future<double> getVolume(AudioSink sink) async => 100.0;
}
