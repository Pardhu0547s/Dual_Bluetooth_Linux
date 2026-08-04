class AudioSink {
  final int id;
  final String name;
  final String description;
  final bool isBluetooth;

  AudioSink({
    required this.id,
    required this.name,
    required this.description,
    required this.isBluetooth,
  });

  factory AudioSink.fromJson(Map<String, dynamic> json) {
    final props = (json['info'] ?? {})['props'] ?? {};
    final String nodeName = props['node.name'] ?? 'Node ${json['id']}';
    final String desc = props['node.description'] ?? nodeName;
    final bool isBt = nodeName.contains('bluez') || props['device.api'] == 'bluez5';

    return AudioSink(
      id: json['id'] as int,
      name: nodeName,
      description: desc,
      isBluetooth: isBt,
    );
  }
}

class BluetoothDevice {
  final String mac;
  final String name;
  final bool isConnected;

  BluetoothDevice({
    required this.mac,
    required this.name,
    this.isConnected = false,
  });
}
