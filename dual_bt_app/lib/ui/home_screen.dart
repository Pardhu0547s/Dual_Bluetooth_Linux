import 'package:flutter/material.dart';
import '../models/audio_node.dart';
import '../services/pipewire_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final PipeWireService _service = PipeWireService();
  List<AudioSink> _sinks = [];
  AudioSink? _selectedSink1;
  AudioSink? _selectedSink2;
  double _vol1 = 80;
  double _vol2 = 80;
  bool _isLoading = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _service.onDeviceDisconnected = (deviceName) {
      if (mounted) {
        setState(() {});
        _loadSinks();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Device "$deviceName" disconnected. Restored normal audio output.'),
            backgroundColor: Colors.amber.shade900,
          ),
        );
      }
    };

    _loadSinks();
  }

  @override
  void dispose() {
    _animController.dispose();
    _service.stopDualStream();
    super.dispose();
  }

  Future<void> _loadSinks() async {
    setState(() => _isLoading = true);
    final sinks = await _service.getAudioSinks();
    setState(() {
      _sinks = sinks;
      _isLoading = false;

      if (_sinks.isNotEmpty) {
        _selectedSink1 ??= _sinks.first;
        _selectedSink2 ??= _sinks.length > 1 ? _sinks[1] : _sinks.first;
      }
    });

    if (_selectedSink1 != null) {
      final v1 = await _service.getVolume(_selectedSink1!);
      setState(() => _vol1 = v1);
    }
    if (_selectedSink2 != null) {
      final v2 = await _service.getVolume(_selectedSink2!);
      setState(() => _vol2 = v2);
    }
  }

  Future<void> _toggleStream() async {
    if (_service.isStreaming) {
      await _service.stopDualStream();
      setState(() {});
    } else {
      if (_selectedSink1 == null || _selectedSink2 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select two output sinks.')),
        );
        return;
      }

      final success = await _service.startDualStream(
        target1: _selectedSink1!,
        target2: _selectedSink2!,
      );

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start PipeWire dual stream.')),
          );
        }
      } else {
        await _service.setVolume(_selectedSink1!, _vol1);
        await _service.setVolume(_selectedSink2!, _vol2);
      }
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStreaming = _service.isStreaming;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.8, -0.8),
            radius: 1.2,
            colors: [
              Color(0x1F00F2FE),
              Color(0x000B0E14),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F2FE).withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.bluetooth_audio, color: Colors.black, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dual Audio Hub',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'PipeWire Linux Dual Bluetooth Streamer',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isStreaming ? Colors.green.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: isStreaming ? Colors.green.withOpacity(0.4) : Colors.white.withOpacity(0.1),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              AnimatedBuilder(
                                animation: _animController,
                                builder: (context, child) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isStreaming ? Colors.greenAccent : Colors.grey,
                                      boxShadow: isStreaming
                                          ? [
                                              BoxShadow(
                                                color: Colors.greenAccent.withOpacity(_animController.value),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          : [],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isStreaming ? 'TRANSMITTING DUAL AUDIO' : 'IDLE',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isStreaming ? Colors.greenAccent : Colors.grey.shade400,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white70),
                          tooltip: 'Rescan PipeWire Sinks',
                          onPressed: _loadSinks,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Device Cards Grid
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildDeviceCard(
                          title: 'Device 1 (Headphones A)',
                          selectedSink: _selectedSink1,
                          onSinkChanged: (s) async {
                            setState(() => _selectedSink1 = s);
                            if (s != null) {
                              final v = await _service.getVolume(s);
                              setState(() => _vol1 = v);
                            }
                          },
                          volume: _vol1,
                          onVolumeChanged: (v) {
                            setState(() => _vol1 = v);
                            if (_selectedSink1 != null) {
                              _service.setVolume(_selectedSink1!, v);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _buildDeviceCard(
                          title: 'Device 2 (Headphones B)',
                          selectedSink: _selectedSink2,
                          onSinkChanged: (s) async {
                            setState(() => _selectedSink2 = s);
                            if (s != null) {
                              final v = await _service.getVolume(s);
                              setState(() => _vol2 = v);
                            }
                          },
                          volume: _vol2,
                          onVolumeChanged: (v) {
                            setState(() => _vol2 = v);
                            if (_selectedSink2 != null) {
                              _service.setVolume(_selectedSink2!, v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Master Toggle Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _toggleStream,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    backgroundColor: isStreaming ? Colors.redAccent.shade700 : const Color(0xFF00F2FE),
                    foregroundColor: isStreaming ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: isStreaming
                        ? Colors.redAccent.withOpacity(0.4)
                        : const Color(0xFF00F2FE).withOpacity(0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isStreaming ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 26),
                      const SizedBox(width: 8),
                      Text(
                        isStreaming ? 'Stop Dual Streaming' : 'Start Dual Bluetooth Stream',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceCard({
    required String title,
    required AudioSink? selectedSink,
    required ValueChanged<AudioSink?> onSinkChanged,
    required double volume,
    required ValueChanged<double> onVolumeChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF141822).withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.headphones_rounded, color: Color(0xFF00F2FE), size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const Text(
            'TARGET AUDIO SINK',
            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
          ),
          const SizedBox(height: 10),

          // Dropdown Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0E14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AudioSink>(
                value: selectedSink,
                isExpanded: true,
                dropdownColor: const Color(0xFF141822),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: _sinks.map((sink) {
                  return DropdownMenuItem<AudioSink>(
                    value: sink,
                    child: Row(
                      children: [
                        Icon(
                          sink.isBluetooth ? Icons.bluetooth : Icons.speaker,
                          color: sink.isBluetooth ? const Color(0xFF4FACFE) : Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sink.description,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onSinkChanged,
              ),
            ),
          ),

          const Spacer(),

          // Individual Volume Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    volume == 0 ? Icons.volume_off : (volume < 50 ? Icons.volume_down : Icons.volume_up),
                    color: const Color(0xFF00F2FE),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'DEVICE VOLUME',
                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                  ),
                ],
              ),
              Text(
                '${volume.round()}%',
                style: const TextStyle(color: Color(0xFF00F2FE), fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Slider(
            value: volume.clamp(0.0, 100.0),
            min: 0,
            max: 100,
            divisions: 100,
            activeColor: const Color(0xFF00F2FE),
            inactiveColor: Colors.white.withOpacity(0.1),
            onChanged: onVolumeChanged,
          ),
        ],
      ),
    );
  }
}
