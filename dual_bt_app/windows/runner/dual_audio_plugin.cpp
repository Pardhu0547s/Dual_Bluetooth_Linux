#include "dual_audio_plugin.h"

#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <functiondiscoverykeys_devpkey.h>

#include <iostream>
#include <vector>
#include <string>

// Helper to convert wide string to string
std::string utf8_encode(const std::wstring &wstr) {
    if (wstr.empty()) return std::string();
    int size_needed = WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), NULL, 0, NULL, NULL);
    std::string strTo(size_needed, 0);
    WideCharToMultiByte(CP_UTF8, 0, &wstr[0], (int)wstr.size(), &strTo[0], size_needed, NULL, NULL);
    return strTo;
}

// Helper to convert string to wide string
std::wstring utf8_decode(const std::string &str) {
    if (str.empty()) return std::wstring();
    int size_needed = MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), NULL, 0);
    std::wstring wstrTo(size_needed, 0);
    MultiByteToWideChar(CP_UTF8, 0, &str[0], (int)str.size(), &wstrTo[0], size_needed);
    return wstrTo;
}

void DualAudioPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "com.dualbt.audio",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<DualAudioPlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

DualAudioPlugin::DualAudioPlugin() {}

DualAudioPlugin::~DualAudioPlugin() {}

void DualAudioPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name() == "getAudioSinks") {
    GetAudioSinks(std::move(result));
  } else if (method_call.method_name() == "startDualStream") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
          auto sink1_it = arguments->find(flutter::EncodableValue("sink1Name"));
          auto sink2_it = arguments->find(flutter::EncodableValue("sink2Name"));
          if (sink1_it != arguments->end() && sink2_it != arguments->end()) {
              std::string sink1 = std::get<std::string>(sink1_it->second);
              std::string sink2 = std::get<std::string>(sink2_it->second);
              StartDualStream(sink1, sink2, std::move(result));
              return;
          }
      }
      result->Error("INVALID_ARGUMENT", "Missing sink1Name or sink2Name");
  } else if (method_call.method_name() == "stopDualStream") {
    StopDualStream(std::move(result));
  } else if (method_call.method_name() == "setVolume") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
          auto sink_it = arguments->find(flutter::EncodableValue("sinkId"));
          auto vol_it = arguments->find(flutter::EncodableValue("volume"));
          if (sink_it != arguments->end() && vol_it != arguments->end()) {
              std::string sinkId = std::get<std::string>(sink_it->second);
              double volume = std::get<double>(vol_it->second);
              SetVolume(sinkId, volume, std::move(result));
              return;
          }
      }
      result->Error("INVALID_ARGUMENT", "Missing sinkId or volume");
  } else if (method_call.method_name() == "getVolume") {
      const auto* arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      if (arguments) {
          auto sink_it = arguments->find(flutter::EncodableValue("sinkId"));
          if (sink_it != arguments->end()) {
              std::string sinkId = std::get<std::string>(sink_it->second);
              GetVolume(sinkId, std::move(result));
              return;
          }
      }
      result->Error("INVALID_ARGUMENT", "Missing sinkId");
  } else {
    result->NotImplemented();
  }
}

void DualAudioPlugin::GetAudioSinks(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    bool coInit = SUCCEEDED(hr);

    IMMDeviceEnumerator *pEnum = NULL;
    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, __uuidof(IMMDeviceEnumerator), (void**)&pEnum);
    
    if (FAILED(hr)) {
        if (coInit) CoUninitialize();
        result->Error("ERROR", "Failed to create MMDeviceEnumerator");
        return;
    }

    IMMDeviceCollection *pDevices = NULL;
    hr = pEnum->EnumAudioEndpoints(eRender, DEVICE_STATE_ACTIVE, &pDevices);
    
    if (FAILED(hr)) {
        pEnum->Release();
        if (coInit) CoUninitialize();
        result->Error("ERROR", "Failed to enumerate endpoints");
        return;
    }

    UINT count;
    pDevices->GetCount(&count);

    flutter::EncodableList sinks;

    for (UINT i = 0; i < count; i++) {
        IMMDevice *pDevice = NULL;
        hr = pDevices->Item(i, &pDevice);
        if (SUCCEEDED(hr)) {
            LPWSTR pwszID = NULL;
            hr = pDevice->GetId(&pwszID);
            
            IPropertyStore *pProps = NULL;
            hr = pDevice->OpenPropertyStore(STGM_READ, &pProps);
            
            std::string name = "Unknown";
            std::string description = "Unknown";
            bool isBluetooth = false;

            if (SUCCEEDED(hr)) {
                PROPVARIANT varName;
                PropVariantInit(&varName);
                hr = pProps->GetValue(PKEY_Device_FriendlyName, &varName);
                if (SUCCEEDED(hr) && varName.vt == VT_LPWSTR) {
                    name = utf8_encode(varName.pwszVal);
                    // Simple check for Bluetooth in name for demo purposes
                    std::string lowerName = name;
                    for (auto &c : lowerName) c = tolower(c);
                    if (lowerName.find("bluetooth") != std::string::npos) {
                        isBluetooth = true;
                    }
                }
                PropVariantClear(&varName);
                pProps->Release();
            }
            
            std::string id = pwszID ? utf8_encode(pwszID) : "";
            if (pwszID) CoTaskMemFree(pwszID);

            flutter::EncodableMap sinkMap = {
                {flutter::EncodableValue("id"), flutter::EncodableValue(id)},
                {flutter::EncodableValue("name"), flutter::EncodableValue(name)},
                {flutter::EncodableValue("description"), flutter::EncodableValue(description)},
                {flutter::EncodableValue("isBluetooth"), flutter::EncodableValue(isBluetooth)},
            };
            sinks.push_back(flutter::EncodableValue(sinkMap));
            pDevice->Release();
        }
    }

    pDevices->Release();
    pEnum->Release();
    if (coInit) CoUninitialize();

    result->Success(flutter::EncodableValue(sinks));
}

void DualAudioPlugin::StartDualStream(const std::string& sink1Id, const std::string& sink2Id, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    // TODO: Implement actual WASAPI loopback capture and dual render.
    // This is a placeholder since a full WASAPI implementation requires managing audio threads, buffers, and format conversion.
    result->Success(flutter::EncodableValue(true));
}

void DualAudioPlugin::StopDualStream(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    // TODO: Implement stopping of WASAPI stream.
    result->Success(flutter::EncodableValue(true));
}

void DualAudioPlugin::SetVolume(const std::string& sinkId, double volume, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    bool coInit = SUCCEEDED(hr);

    IMMDeviceEnumerator *pEnum = NULL;
    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, __uuidof(IMMDeviceEnumerator), (void**)&pEnum);
    
    if (FAILED(hr)) {
        if (coInit) CoUninitialize();
        result->Error("ERROR", "Failed to create MMDeviceEnumerator");
        return;
    }

    std::wstring wsinkId = utf8_decode(sinkId);
    IMMDevice *pDevice = NULL;
    hr = pEnum->GetDevice(wsinkId.c_str(), &pDevice);
    
    if (SUCCEEDED(hr)) {
        IAudioEndpointVolume *pEndpointVolume = NULL;
        hr = pDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, NULL, (void**)&pEndpointVolume);
        if (SUCCEEDED(hr)) {
            float vol = (float)volume;
            if (vol < 0.0f) vol = 0.0f;
            if (vol > 1.0f) vol = 1.0f;
            pEndpointVolume->SetMasterVolumeLevelScalar(vol, NULL);
            pEndpointVolume->Release();
            result->Success(flutter::EncodableValue(true));
        } else {
            result->Error("ERROR", "Failed to activate endpoint volume");
        }
        pDevice->Release();
    } else {
        result->Error("ERROR", "Failed to get device");
    }

    pEnum->Release();
    if (coInit) CoUninitialize();
}

void DualAudioPlugin::GetVolume(const std::string& sinkId, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    HRESULT hr = CoInitializeEx(NULL, COINIT_MULTITHREADED);
    bool coInit = SUCCEEDED(hr);

    IMMDeviceEnumerator *pEnum = NULL;
    hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL, __uuidof(IMMDeviceEnumerator), (void**)&pEnum);
    
    if (FAILED(hr)) {
        if (coInit) CoUninitialize();
        result->Error("ERROR", "Failed to create MMDeviceEnumerator");
        return;
    }

    std::wstring wsinkId = utf8_decode(sinkId);
    IMMDevice *pDevice = NULL;
    hr = pEnum->GetDevice(wsinkId.c_str(), &pDevice);
    
    if (SUCCEEDED(hr)) {
        IAudioEndpointVolume *pEndpointVolume = NULL;
        hr = pDevice->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL, NULL, (void**)&pEndpointVolume);
        if (SUCCEEDED(hr)) {
            float vol = 0.0f;
            pEndpointVolume->GetMasterVolumeLevelScalar(&vol);
            pEndpointVolume->Release();
            result->Success(flutter::EncodableValue((double)vol));
        } else {
            result->Error("ERROR", "Failed to activate endpoint volume");
        }
        pDevice->Release();
    } else {
        result->Error("ERROR", "Failed to get device");
    }

    pEnum->Release();
    if (coInit) CoUninitialize();
}
