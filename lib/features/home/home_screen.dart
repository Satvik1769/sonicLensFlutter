import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/song.dart';
import '../../core/providers/app_provider.dart';
import '../../core/services/audio_capture_service.dart';
import '../../core/theme/app_theme.dart';

// ignore_for_file: use_build_context_synchronously

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _syncAnimation(CaptureState state) {
    if (state == CaptureState.listening) {
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.animateTo(0.85, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      _syncAnimation(provider.captureState);

      final result = provider.latestRecognition;

      return Scaffold(
        body: SafeArea(
          child: result != null
              ? _ResultView(song: result, provider: provider)
              : Column(
                  children: [
                    _buildHeader(provider),
                    Expanded(child: _buildRadar(provider)),
                    // Android only: backend switcher (Shizuku vs mic)
                    if (AudioCaptureService.isSupported)
                      _BackendSwitcher(provider: provider),
                    _buildStatusArea(provider),
                    const SizedBox(height: 32),
                  ],
                ),
        ),
      );
    });
  }

  Widget _buildHeader(AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'SonicLens',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          Row(
            children: [
              // Android: Shizuku badge. iOS: mic badge.
              if (AudioCaptureService.isSupported)
                _ShizukuBadge(available: provider.shizukuAvailable)
              else
                const _MicBadge(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
                tooltip: 'Log out',
                onPressed: () => provider.logout(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadar(AppProvider provider) {
    final isListening = provider.captureState == CaptureState.listening;
    final isStarting = provider.captureState == CaptureState.starting;

    return Center(
      child: GestureDetector(
        onTap: isStarting ? null : provider.toggleCapture,
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            final scale = isListening ? _pulseAnim.value : 1.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                if (isListening) ...[
                  _RadarRing(radius: 155 * scale, color: AppTheme.radarOuter),
                  _RadarRing(radius: 125 * scale, color: AppTheme.radarMiddle),
                ],
                // Main button
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: isListening
                            ? [AppTheme.radarGlow, AppTheme.radarInner]
                            : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                      ),
                      boxShadow: isListening
                          ? [
                              BoxShadow(
                                color: AppTheme.radarInner.withValues(alpha: 0.5),
                                blurRadius: 40,
                                spreadRadius: 8,
                              ),
                            ]
                          : [],
                      border: Border.all(
                        color: isListening ? AppTheme.radarGlow : Colors.white12,
                        width: 2,
                      ),
                    ),
                    child: child,
                  ),
                ),
              ],
            );
          },
          child: _ButtonContent(
            state: provider.captureState,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusArea(AppProvider provider) {
    if (provider.captureState == CaptureState.error &&
        provider.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
          ),
          child: Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
          ),
        ),
      );
    }

    final isMic = provider.backend == CaptureBackend.microphone;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        provider.captureState == CaptureState.listening
            ? (isMic ? 'Listening via microphone...' : 'Listening to system audio...')
            : (isMic ? 'Tap and hold phone near speaker' : 'Tap to start listening'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white54, fontSize: 16),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final CaptureState state;
  const _ButtonContent({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state == CaptureState.starting) {
      return const CircularProgressIndicator(
        color: Colors.white,
        strokeWidth: 2,
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          state == CaptureState.listening
              ? Icons.graphic_eq_rounded
              : Icons.music_note_rounded,
          color: Colors.white,
          size: 48,
        ),
        const SizedBox(height: 8),
        Text(
          state == CaptureState.listening ? 'LISTENING' : 'TAP',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

class _RadarRing extends StatelessWidget {
  final double radius;
  final Color color;
  const _RadarRing({required this.radius, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final RecognizedSong song;
  final AppProvider provider;
  const _ResultView({required this.song, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with back button
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70),
                onPressed: provider.clearRecognition,
              ),
              const Spacer(),
              const Text(
                'SonicLens',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48), // balance the back button
            ],
          ),
        ),

        const Spacer(),

        // Artwork
        Container(
          width: 220,
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.radarInner.withValues(alpha: 0.4),
                blurRadius: 48,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: song.artworkUrl != null
                ? Image.network(
                    song.artworkUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _PlaceholderArt(size: 220),
                  )
                : const _PlaceholderArt(size: 220),
          ),
        ),

        const SizedBox(height: 32),

        // Match badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.radarGlow.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.radarGlow.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppTheme.radarGlow, size: 14),
              const SizedBox(width: 6),
              Text(
                'Match found · ${(song.confidence * 100).round()}%',
                style: const TextStyle(
                  color: AppTheme.radarGlow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Title + Artist
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            song.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            song.artist,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 16),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (song.album != null) ...[
          const SizedBox(height: 4),
          Text(
            song.album!,
            style: const TextStyle(color: Colors.white38, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const Spacer(),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              if (song.spotifyUrl != null)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text(
                      'Open in Spotify',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    onPressed: () => launchUrl(
                      Uri.parse(song.spotifyUrl!),
                      mode: LaunchMode.externalApplication,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text(
                    'Listen Again',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  onPressed: provider.clearRecognition,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),
      ],
    );
  }
}

class _PlaceholderArt extends StatelessWidget {
  final double size;
  const _PlaceholderArt({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note, color: Colors.white24),
    );
  }
}

/// Android-only row to switch between Shizuku (system audio) and microphone.
class _BackendSwitcher extends StatelessWidget {
  final AppProvider provider;
  const _BackendSwitcher({required this.provider});

  @override
  Widget build(BuildContext context) {
    final active = provider.backend;
    final canSwitch = provider.captureState != CaptureState.listening;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Chip(
            label: 'System Audio',
            icon: Icons.speaker,
            selected: active == CaptureBackend.shizuku,
            enabled: canSwitch && provider.shizukuAvailable,
            onTap: () => provider.switchBackend(CaptureBackend.shizuku),
          ),
          const SizedBox(width: 8),
          _Chip(
            label: 'Microphone',
            icon: Icons.mic,
            selected: active == CaptureBackend.microphone,
            enabled: canSwitch,
            onTap: () => provider.switchBackend(CaptureBackend.microphone),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.radarInner.withValues(alpha: 0.2)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.radarInner : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected
                    ? AppTheme.radarGlow
                    : enabled
                        ? Colors.white54
                        : Colors.white24),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppTheme.radarGlow
                    : enabled
                        ? Colors.white54
                        : Colors.white24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MicBadge extends StatelessWidget {
  const _MicBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic, size: 12, color: Colors.lightBlueAccent),
          SizedBox(width: 4),
          Text(
            'Microphone',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.lightBlueAccent,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShizukuBadge extends StatelessWidget {
  final bool available;
  const _ShizukuBadge({required this.available});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: available
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: available ? Colors.green.withValues(alpha: 0.5) : Colors.orange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.check_circle : Icons.warning_amber,
            size: 12,
            color: available ? Colors.greenAccent : Colors.orangeAccent,
          ),
          const SizedBox(width: 4),
          Text(
            'Shizuku',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: available ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ),
        ],
      ),
    );
  }
}