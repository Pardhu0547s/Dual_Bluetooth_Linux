import Cocoa
import FlutterMacOS
import CoreAudio

public class DualAudioPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.dualbt.audio", binaryMessenger: registrar.messenger)
    let instance = DualAudioPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAudioSinks":
      getAudioSinks(result: result)
    case "startDualStream":
      if let args = call.arguments as? [String: Any],
         let sink1 = args["sink1Name"] as? String,
         let sink2 = args["sink2Name"] as? String {
        startDualStream(sink1Name: sink1, sink2Name: sink2, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing sink names", details: nil))
      }
    case "stopDualStream":
      stopDualStream(result: result)
    case "setVolume":
      if let args = call.arguments as? [String: Any],
         let sinkId = args["sinkId"] as? String,
         let volume = args["volume"] as? Double {
        setVolume(sinkId: sinkId, volume: volume, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing sinkId or volume", details: nil))
      }
    case "getVolume":
      if let args = call.arguments as? [String: Any],
         let sinkId = args["sinkId"] as? String {
        getVolume(sinkId: sinkId, result: result)
      } else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing sinkId", details: nil))
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getAudioSinks(result: @escaping FlutterResult) {
    var propertyAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
    guard status == noErr else {
      result(FlutterError(code: "CORE_AUDIO_ERROR", message: "Failed to get device list size", details: nil))
      return
    }

    let deviceCount = Int(dataSize / UInt32(MemoryLayout<AudioDeviceID>.size))
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
    status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
    guard status == noErr else {
      result(FlutterError(code: "CORE_AUDIO_ERROR", message: "Failed to get device list", details: nil))
      return
    }

    var sinks: [[String: Any]] = []

    for deviceID in deviceIDs {
      // Check if it's an output device
      var streamAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyStreams,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
      )
      var streamDataSize: UInt32 = 0
      AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamDataSize)
      if streamDataSize == 0 { continue } // Not an output device

      var nameAddress = AudioObjectPropertyAddress(
        mSelector: kAudioObjectPropertyName,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var name: CFString = "" as CFString
      var nameSize = UInt32(MemoryLayout<CFString>.size)
      status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)
      
      let deviceName = status == noErr ? (name as String) : "Unknown"
      let isBluetooth = deviceName.lowercased().contains("bluetooth") || deviceName.lowercased().contains("airpods")

      var uidAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var uid: CFString = "" as CFString
      var uidSize = UInt32(MemoryLayout<CFString>.size)
      status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uid)
      let deviceUID = status == noErr ? (uid as String) : String(deviceID)

      sinks.append([
        "id": deviceUID,
        "name": deviceName,
        "description": "CoreAudio Device",
        "isBluetooth": isBluetooth
      ])
    }

    result(sinks)
  }

  private func startDualStream(sink1Name: String, sink2Name: String, result: @escaping FlutterResult) {
    // Note: Creating an aggregate device properly requires C-style CoreAudio API calls
    // with AudioHardwareCreateAggregateDevice, defining sub-devices via dictionary.
    // This is a placeholder for actual aggregate device creation.
    result(true)
  }

  private func stopDualStream(result: @escaping FlutterResult) {
    // Placeholder to destroy aggregate device and reset default output
    result(true)
  }

  private func setVolume(sinkId: String, volume: Double, result: @escaping FlutterResult) {
    // Assuming sinkId is UID. We need to find deviceID from UID to set volume.
    // Simplified logic: find device ID by name or UID
    var deviceID = findDeviceID(uid: sinkId)
    if deviceID == 0 {
       result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Sink ID not found", details: nil))
       return
    }

    var vol = Float32(max(0.0, min(1.0, volume)))
    var volAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectSetPropertyData(deviceID, &volAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &vol)
    if status == noErr {
      result(true)
    } else {
      result(FlutterError(code: "VOLUME_ERROR", message: "Failed to set volume", details: status))
    }
  }

  private func getVolume(sinkId: String, result: @escaping FlutterResult) {
    var deviceID = findDeviceID(uid: sinkId)
    if deviceID == 0 {
       result(FlutterError(code: "DEVICE_NOT_FOUND", message: "Sink ID not found", details: nil))
       return
    }

    var vol: Float32 = 0.0
    var dataSize = UInt32(MemoryLayout<Float32>.size)
    var volAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )

    let status = AudioObjectGetPropertyData(deviceID, &volAddress, 0, nil, &dataSize, &vol)
    if status == noErr {
      result(Double(vol))
    } else {
      result(FlutterError(code: "VOLUME_ERROR", message: "Failed to get volume", details: status))
    }
  }

  private func findDeviceID(uid: String) -> AudioDeviceID {
    var propertyAddress = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDevices,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )

    var dataSize: UInt32 = 0
    var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
    if status != noErr { return 0 }

    let deviceCount = Int(dataSize / UInt32(MemoryLayout<AudioDeviceID>.size))
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
    status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &deviceIDs)
    if status != noErr { return 0 }

    for deviceID in deviceIDs {
      var uidAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceUID,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
      )
      var currentUID: CFString = "" as CFString
      var uidSize = UInt32(MemoryLayout<CFString>.size)
      status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &currentUID)
      
      if status == noErr && (currentUID as String) == uid {
        return deviceID
      }
    }
    return 0
  }
}
