#ifndef DUAL_AUDIO_PLUGIN_H_
#define DUAL_AUDIO_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <memory>

class DualAudioPlugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  DualAudioPlugin();
  virtual ~DualAudioPlugin();

private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void GetAudioSinks(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StartDualStream(const std::string& sink1Id, const std::string& sink2Id, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void StopDualStream(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SetVolume(const std::string& sinkId, double volume, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void GetVolume(const std::string& sinkId, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif  // DUAL_AUDIO_PLUGIN_H_
