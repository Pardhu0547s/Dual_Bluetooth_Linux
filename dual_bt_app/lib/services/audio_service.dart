import '../models/audio_node.dart';

/// Abstract audio service interface for cross-platform dual Bluetooth streaming.
/// Each platform (Linux, macOS, Windows) provides its own implementation.
abstract class AudioService {
  bool get isStreaming;

  /// Callback triggered when a Bluetooth device disconnects during streaming.
  Function(String deviceName)? onDeviceDisconnected;

  /// Discovers available audio output sinks on the system.
  Future<List<AudioSink>> getAudioSinks();

  /// Starts dual audio streaming to two target sinks.
  Future<bool> startDualStream({
    required AudioSink target1,
    required AudioSink target2,
  });

  /// Stops dual streaming and restores the original default audio output.
  Future<void> stopDualStream();

  /// Sets volume (0-100) for a specific audio sink.
  Future<void> setVolume(AudioSink sink, double volumePercent);

  /// Gets the current volume (0-100) for a specific audio sink.
  Future<double> getVolume(AudioSink sink);

  /// Returns the name of the current platform for display purposes.
  String get platformName;

  /// Whether the platform supports programmatic dual audio routing.
  bool get supportsDualAudio;
}
