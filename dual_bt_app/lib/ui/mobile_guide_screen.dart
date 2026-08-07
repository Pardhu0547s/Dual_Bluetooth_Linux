import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Instructional guide screen for Android and iOS users.
/// These platforms cannot programmatically route dual Bluetooth audio,
/// so we show clear step-by-step instructions for built-in OS features.
class MobileGuideScreen extends StatelessWidget {
  const MobileGuideScreen({super.key});

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGlow),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.bluetooth_audio_rounded, color: Colors.white, size: 36),
                      ),
                      const SizedBox(height: 20),
                      const Text('Dual Audio Hub', style: AppTheme.headingLg),
                      const SizedBox(height: 8),
                      Text(
                        'Dual Bluetooth streaming guide for ${_isAndroid ? 'Android' : 'iOS'}',
                        style: AppTheme.bodyMd,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Platform limitation notice
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.warning.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Platform Limitation',
                              style: AppTheme.headingSm.copyWith(color: AppTheme.warning),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isAndroid
                                  ? 'Android does not allow third-party apps to route audio to two Bluetooth devices simultaneously. Use your device\'s built-in features below.'
                                  : 'iOS restricts Bluetooth audio routing to one device. Use Apple\'s built-in Audio Sharing for AirPods / Beats.',
                              style: AppTheme.bodyMd,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Instructions
                if (_isAndroid) ..._buildAndroidGuide() else ..._buildIOSGuide(),

                const SizedBox(height: 32),

                // Desktop promotion
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.cardDecoration(),
                  child: Column(
                    children: [
                      const Icon(Icons.desktop_mac_rounded, color: AppTheme.accent, size: 36),
                      const SizedBox(height: 12),
                      const Text('Full Features on Desktop', style: AppTheme.headingSm),
                      const SizedBox(height: 8),
                      Text(
                        'For full programmatic dual Bluetooth audio streaming with volume control, install Dual Audio Hub on Linux, macOS, or Windows.',
                        style: AppTheme.bodyMd,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildPlatformChip(Icons.laptop_chromebook, 'Linux'),
                          const SizedBox(width: 8),
                          _buildPlatformChip(Icons.desktop_mac, 'macOS'),
                          const SizedBox(width: 8),
                          _buildPlatformChip(Icons.desktop_windows, 'Windows'),
                        ],
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

  List<Widget> _buildAndroidGuide() {
    return [
      const Text('How to Enable Dual Audio', style: AppTheme.headingMd),
      const SizedBox(height: 20),

      _buildGuideSection(
        title: 'Samsung Galaxy (Dual Audio)',
        icon: Icons.phone_android_rounded,
        color: const Color(0xFF4FACFE),
        steps: [
          'Connect two Bluetooth headphones or speakers.',
          'Go to Settings → Connections → Bluetooth.',
          'Tap ⋮ (menu) → Advanced → Dual Audio → Turn On.',
          'Open Media Output panel (Volume → Media Output icon).',
          'Select both devices to stream simultaneously.',
        ],
      ),
      const SizedBox(height: 20),

      _buildGuideSection(
        title: 'Bluetooth LE Audio / Auracast',
        icon: Icons.broadcast_on_personal_rounded,
        color: const Color(0xFFA855F7),
        steps: [
          'Requires Android 13+ and LE Audio compatible hardware.',
          'Requires Pixel 8/9, Galaxy S23/S24, or newer chipsets.',
          'Go to Settings → Bluetooth → Paired Devices.',
          'Tap the gear icon on a LE Audio device → Enable Auracast.',
          'Both devices will receive the same broadcast stream.',
        ],
      ),
    ];
  }

  List<Widget> _buildIOSGuide() {
    return [
      const Text('How to Share Audio', style: AppTheme.headingMd),
      const SizedBox(height: 20),

      _buildGuideSection(
        title: 'AirPods / Beats Audio Sharing',
        icon: Icons.earbuds_rounded,
        color: const Color(0xFF4FACFE),
        steps: [
          'Connect your AirPods or Beats headphones.',
          'Open Control Center → tap the AirPlay icon.',
          'Tap "Share Audio…" at the bottom.',
          'Bring the second pair of AirPods / Beats close to your device.',
          'Tap "Share Audio" when the second device appears.',
          'Both headphones will now receive the same audio!',
        ],
      ),
      const SizedBox(height: 20),

      _buildGuideSection(
        title: 'Requirements',
        icon: Icons.checklist_rounded,
        color: const Color(0xFFFFAB40),
        steps: [
          'Both devices must be AirPods or compatible Beats.',
          'iPhone 8 or later with iOS 13+.',
          'Audio Sharing does NOT work with generic Bluetooth headphones.',
        ],
      ),
    ];
  }

  Widget _buildGuideSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> steps,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Text(title, style: AppTheme.headingSm),
            ],
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: AppTheme.bodyMd.copyWith(color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlatformChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 16),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.bodySm.copyWith(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
