import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/audio_node.dart';
import '../services/audio_service.dart';
import '../services/audio_service_factory.dart';
import 'theme.dart';
import 'mobile_guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late final AudioService _service;
  List<AudioSink> _sinks = [];
  AudioSink? _selectedSink1;
  AudioSink? _selectedSink2;
  double _vol1 = 80;
  double _vol2 = 80;
  bool _isLoading = false;

  late final AnimationController _pulseController;
  late final AnimationController _slideController;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _service = AudioServiceFactory.create();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );

    if (!_service.supportsDualAudio) return;

    _service.onDeviceDisconnected = (deviceName) async {
      await _service.stopDualStream();
      if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
        exit(0);
      }
    };

    _loadSinks();
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
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
        _showSnackBar('Please select two audio output devices.', AppTheme.warning);
        return;
      }

      setState(() => _isLoading = true);
      final success = await _service.startDualStream(
        target1: _selectedSink1!,
        target2: _selectedSink2!,
      );
      setState(() => _isLoading = false);

      if (!success) {
        _showSnackBar('Failed to start dual audio stream.', AppTheme.error);
      } else {
        await _service.setVolume(_selectedSink1!, _vol1);
        await _service.setVolume(_selectedSink2!, _vol2);
        _showSnackBar('Dual audio streaming active! 🎧', AppTheme.success);
      }
      setState(() {});
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: AppTheme.bodyMd.copyWith(color: AppTheme.textPrimary))),
          ],
        ),
        backgroundColor: AppTheme.surface,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_service.supportsDualAudio) {
      return const MobileGuideScreen();
    }

    final isStreaming = _service.isStreaming;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGlow),
        child: SafeArea(
          child: FadeTransition(
            opacity: _slideAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(_slideAnimation),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 48 : 24,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // ─── Header ──────────────────────────────
                    _buildHeader(isStreaming),
                    const SizedBox(height: 32),

                    // ─── Device Cards ────────────────────────
                    Expanded(
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: _buildDeviceCard(
                                  index: 1,
                                  icon: Icons.headphones_rounded,
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
                                    if (_selectedSink1 != null) _service.setVolume(_selectedSink1!, v);
                                  },
                                )),
                                const SizedBox(width: 20),
                                // Center connector
                                _buildConnector(isStreaming),
                                const SizedBox(width: 20),
                                Expanded(child: _buildDeviceCard(
                                  index: 2,
                                  icon: Icons.earbuds_rounded,
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
                                    if (_selectedSink2 != null) _service.setVolume(_selectedSink2!, v);
                                  },
                                )),
                              ],
                            )
                          : ListView(
                              children: [
                                _buildDeviceCard(
                                  index: 1,
                                  icon: Icons.headphones_rounded,
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
                                    if (_selectedSink1 != null) _service.setVolume(_selectedSink1!, v);
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildDeviceCard(
                                  index: 2,
                                  icon: Icons.earbuds_rounded,
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
                                    if (_selectedSink2 != null) _service.setVolume(_selectedSink2!, v);
                                  },
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),

                    // ─── Master Control Button ───────────────
                    _buildMasterButton(isStreaming),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeader(bool isStreaming) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // App icon
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accent.withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.bluetooth_audio_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dual Audio Hub', style: AppTheme.headingLg),
              const SizedBox(height: 2),
              Text(
                _service.platformName,
                style: AppTheme.bodySm.copyWith(color: AppTheme.accent.withOpacity(0.8)),
              ),
            ],
          ),
        ),
        // Status Chip
        _buildStatusChip(isStreaming),
        const SizedBox(width: 8),
        // Refresh button
        _buildIconButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Rescan Devices',
          onTap: _loadSinks,
        ),
      ],
    );
  }

  Widget _buildStatusChip(bool isStreaming) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isStreaming ? AppTheme.success.withOpacity(0.1) : AppTheme.surfaceLight.withOpacity(0.5),
        border: Border.all(
          color: isStreaming ? AppTheme.success.withOpacity(0.3) : AppTheme.surfaceBorder,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isStreaming ? AppTheme.success : AppTheme.textMuted,
                  boxShadow: isStreaming
                      ? [BoxShadow(
                          color: AppTheme.success.withOpacity(_pulseController.value * 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )]
                      : [],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            isStreaming ? 'STREAMING' : 'IDLE',
            style: AppTheme.label.copyWith(
              color: isStreaming ? AppTheme.success : AppTheme.textMuted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: AppTheme.glassDecoration(),
          child: Icon(icon, color: AppTheme.textSecondary, size: 20),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CENTER CONNECTOR (desktop wide layout)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildConnector(bool isStreaming) {
    return SizedBox(
      width: 48,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isStreaming ? AppTheme.activeGradient : null,
                    color: isStreaming ? null : AppTheme.surfaceLight,
                    boxShadow: isStreaming
                        ? [BoxShadow(
                            color: AppTheme.success.withOpacity(0.3 + _pulseController.value * 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )]
                        : [],
                  ),
                  child: Icon(
                    isStreaming ? Icons.link_rounded : Icons.link_off_rounded,
                    color: isStreaming ? Colors.white : AppTheme.textMuted,
                    size: 20,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Container(
              width: 2,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isStreaming
                      ? [AppTheme.success.withOpacity(0.5), AppTheme.success.withOpacity(0.05)]
                      : [AppTheme.surfaceBorder, AppTheme.surfaceBorder.withOpacity(0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DEVICE CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDeviceCard({
    required int index,
    required IconData icon,
    required AudioSink? selectedSink,
    required ValueChanged<AudioSink?> onSinkChanged,
    required double volume,
    required ValueChanged<double> onVolumeChanged,
  }) {
    final isStreaming = _service.isStreaming;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(isActive: isStreaming),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: index == 1 ? AppTheme.primaryGradient : const LinearGradient(
                    colors: [Color(0xFFA855F7), Color(0xFF7C3AED)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Device $index',
                      style: AppTheme.headingSm,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      index == 1 ? 'Primary Output' : 'Secondary Output',
                      style: AppTheme.bodySm,
                    ),
                  ],
                ),
              ),
              if (selectedSink != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selectedSink.isBluetooth
                        ? AppTheme.accent.withOpacity(0.1)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selectedSink.isBluetooth
                          ? AppTheme.accent.withOpacity(0.3)
                          : AppTheme.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selectedSink.isBluetooth ? Icons.bluetooth : Icons.speaker_rounded,
                        size: 12,
                        color: selectedSink.isBluetooth ? AppTheme.accent : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedSink.isBluetooth ? 'Bluetooth' : 'Wired',
                        style: AppTheme.label.copyWith(
                          color: selectedSink.isBluetooth ? AppTheme.accent : AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Sink Selector
          Text('AUDIO SINK', style: AppTheme.label),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.background.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.surfaceBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AudioSink>(
                value: selectedSink,
                isExpanded: true,
                dropdownColor: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                style: AppTheme.bodyMd.copyWith(color: AppTheme.textPrimary),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted, size: 20),
                items: _sinks.map((sink) {
                  return DropdownMenuItem<AudioSink>(
                    value: sink,
                    child: Row(
                      children: [
                        Icon(
                          sink.isBluetooth ? Icons.bluetooth : Icons.speaker_rounded,
                          color: sink.isBluetooth ? AppTheme.accent : AppTheme.textMuted,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            sink.description,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.bodyMd.copyWith(color: AppTheme.textPrimary),
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

          // Volume Control
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                volume == 0 ? Icons.volume_off_rounded : (volume < 50 ? Icons.volume_down_rounded : Icons.volume_up_rounded),
                color: AppTheme.accent,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text('VOLUME', style: AppTheme.label),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${volume.round()}%',
                  style: AppTheme.label.copyWith(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: volume.clamp(0.0, 100.0),
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: onVolumeChanged,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  MASTER CONTROL BUTTON
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMasterButton(bool isStreaming) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _isLoading ? null : _toggleStream,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: isStreaming ? AppTheme.dangerGradient : AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: (isStreaming ? AppTheme.error : AppTheme.accent).withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
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
                  color: Colors.white,
                  size: 24,
                ),
              const SizedBox(width: 10),
              Text(
                _isLoading
                    ? 'Connecting...'
                    : isStreaming
                        ? 'Stop Dual Stream'
                        : 'Start Dual Stream',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
