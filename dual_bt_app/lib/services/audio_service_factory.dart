import 'dart:io' show Platform;
import 'audio_service.dart';
import 'linux_audio_service.dart';
import 'macos_audio_service.dart';
import 'windows_audio_service.dart';
import 'mobile_guide_service.dart';

/// Factory that returns the correct AudioService implementation
/// based on the current platform.
class AudioServiceFactory {
  static AudioService create() {
    if (Platform.isLinux) {
      return LinuxAudioService();
    } else if (Platform.isMacOS) {
      return MacOSAudioService();
    } else if (Platform.isWindows) {
      return WindowsAudioService();
    } else {
      // Android, iOS, Fuchsia
      return MobileGuideService();
    }
  }
}
