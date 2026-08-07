import 'dart:io';
import 'package:flutter/material.dart';
import '../models/audio_node.dart';
import '../services/linux_audio_service.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final LinuxAudioService _service = LinuxAudioService();
  List<AudioSink> _sinks = [];
  AudioSink? _selectedSink1;
  AudioSink? _selectedSink2;
  double _vol1 = 100;
  double _vol2 = 100;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _service.onDeviceDisconnected = (deviceName) async {
      print('Bluetooth device $deviceName disconnected. Restoring audio output and closing app.');
      await _service.stopDualStream();
      exit(0);
    };

    _loadSinks();
  }

  @override
  void dispose() {
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
        if (_selectedSink1 == null || !_sinks.any((s) => s.name == _selectedSink1!.name)) {
          _selectedSink1 = _sinks.first;
        } else {
          _selectedSink1 = _sinks.firstWhere((s) => s.name == _selectedSink1!.name);
        }

        if (_selectedSink2 == null || !_sinks.any((s) => s.name == _selectedSink2!.name)) {
          _selectedSink2 = _sinks.length > 1 ? _sinks[1] : _sinks.first;
        } else {
          _selectedSink2 = _sinks.firstWhere((s) => s.name == _selectedSink2!.name);
        }
      } else {
        _selectedSink1 = null;
        _selectedSink2 = null;
      }
    });

    if (_selectedSink1 != null) {
      final v1 = await _service.getVolume(_selectedSink1!);
      if (mounted) setState(() => _vol1 = v1);
    }
    if (_selectedSink2 != null) {
      final v2 = await _service.getVolume(_selectedSink2!);
      if (mounted) setState(() => _vol2 = v2);
    }
  }

  Future<void> _toggleStream() async {
    if (_service.isStreaming) {
      await _service.stopDualStream();
      setState(() {});
    } else {
      if (_selectedSink1 == null || _selectedSink2 == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select two audio output sinks.')),
        );
        return;
      }

      setState(() => _isLoading = true);
      final success = await _service.startDualStream(
        target1: _selectedSink1!,
        target2: _selectedSink2!,
      );
      setState(() => _isLoading = false);

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
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            children: [
              // Top Header
              _buildHeader(isStreaming),
              const SizedBox(height: 24),

              // Device Cards Side-by-Side Grid
              Expanded(
                child: Row(
                  children: [
                    // Device 1 Card (Dark Theme)
                    Expanded(
                      child: _buildDeviceCard1(),
                    ),
                    const SizedBox(width: 24),

                    // Device 2 Card (Light High-Contrast Theme)
                    Expanded(
                      child: _buildDeviceCard2(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Master Control Button
              _buildMasterButton(isStreaming),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TOP HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(bool isStreaming) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // 3D Metallic Silver App Icon Container
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset(
                  'assets/image.png',
                  fit: BoxFit.cover,
                ),
              ),
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
                  'Linux (PipeWire)',
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
            // Status Badge Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E26),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2E3342)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isStreaming ? Colors.greenAccent : Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isStreaming ? 'STREAMING' : 'IDLE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isStreaming ? Colors.greenAccent : Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Refresh Button
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2E3342)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                tooltip: 'Rescan PipeWire Sinks',
                onPressed: _loadSinks,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DEVICE 1 CARD (Dark Theme)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDeviceCard1() {
    final sink = _selectedSink1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardDarkBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.headphones_rounded, color: Colors.white, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device 1',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Primary Output',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Device Type Badge
              if (sink != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.darkInset,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.darkInsetBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sink.isBluetooth ? Icons.bluetooth : Icons.speaker,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sink.isBluetooth ? 'Bluetooth' : 'Wired',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // AUDIO SINK Label
          Text(
            'AUDIO SINK',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          // Dropdown Container (Dark Theme)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.darkInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.darkInsetBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AudioSink>(
                value: _selectedSink1,
                isExpanded: true,
                dropdownColor: AppTheme.cardDark,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                items: _sinks.map((item) {
                  return DropdownMenuItem<AudioSink>(
                    value: item,
                    child: Row(
                      children: [
                        Icon(
                          item.isBluetooth ? Icons.bluetooth : Icons.speaker,
                          color: Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.description,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (s) async {
                  setState(() => _selectedSink1 = s);
                  if (s != null) {
                    final v = await _service.getVolume(s);
                    setState(() => _vol1 = v);
                  }
                },
              ),
            ),
          ),

          const Spacer(),

          // Volume Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.volume_up_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'VOLUME',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkInset,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.darkInsetBorder),
                ),
                child: Text(
                  '${_vol1.round()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Custom White Slider for Device 1
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: Colors.white,
              inactiveTrackColor: const Color(0xFF2E3342),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayColor: Colors.white.withOpacity(0.12),
            ),
            child: Slider(
              value: _vol1.clamp(0.0, 100.0),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (v) {
                setState(() => _vol1 = v);
                if (_selectedSink1 != null) {
                  _service.setVolume(_selectedSink1!, v);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DEVICE 2 CARD (Light High-Contrast Theme)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDeviceCard2() {
    final sink = _selectedSink2;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardLightBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.headphones_rounded, color: Colors.black, size: 42),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device 2',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Secondary Output',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // Device Type Badge
              if (sink != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        sink.isBluetooth ? Icons.bluetooth : Icons.speaker,
                        size: 14,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        sink.isBluetooth ? 'Bluetooth' : 'Wired',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // AUDIO SINK Label
          const Text(
            'AUDIO SINK',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          // Dropdown Container (Light Theme)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFCBD5E1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AudioSink>(
                value: _selectedSink2,
                isExpanded: true,
                dropdownColor: Colors.white,
                style: const TextStyle(color: Colors.black, fontSize: 14),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black87),
                items: _sinks.map((item) {
                  return DropdownMenuItem<AudioSink>(
                    value: item,
                    child: Row(
                      children: [
                        Icon(
                          item.isBluetooth ? Icons.bluetooth : Icons.speaker,
                          color: Colors.black87,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.description,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (s) async {
                  setState(() => _selectedSink2 = s);
                  if (s != null) {
                    final v = await _service.getVolume(s);
                    setState(() => _vol2 = v);
                  }
                },
              ),
            ),
          ),

          const Spacer(),

          // Volume Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.volume_up_rounded, color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'VOLUME',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${_vol2.round()}%',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Custom Black Slider for Device 2
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: Colors.black,
              inactiveTrackColor: const Color(0xFFCBD5E1),
              thumbColor: Colors.black,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayColor: Colors.black.withOpacity(0.12),
            ),
            child: Slider(
              value: _vol2.clamp(0.0, 100.0),
              min: 0,
              max: 100,
              divisions: 100,
              onChanged: (v) {
                setState(() => _vol2 = v);
                if (_selectedSink2 != null) {
                  _service.setVolume(_selectedSink2!, v);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MASTER CONTROL BUTTON
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMasterButton(bool isStreaming) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _toggleStream,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20),
          backgroundColor: isStreaming ? Colors.redAccent.shade700 : AppTheme.buttonDark,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isStreaming ? Colors.redAccent : AppTheme.buttonDarkBorder,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(
                isStreaming ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 22,
                color: Colors.white,
              ),
            const SizedBox(width: 8),
            Text(
              isStreaming ? 'Stop Dual Stream' : 'Start Dual Stream',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
