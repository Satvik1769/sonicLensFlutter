import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../core/models/song.dart';
import '../../core/providers/app_provider.dart';
import '../../core/theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _player = AudioPlayer();
  Song? _loadedSong;
  bool _loading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadSong(Song song) async {
    if (_loadedSong?.id == song.id) return;
    setState(() => _loading = true);
    try {
      await _player.setUrl(song.streamUrl!);
      _loadedSong = song;
      await _player.play();
    } catch (e) {
      debugPrint('Player error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final currentSong = provider.currentSong;

      if (currentSong?.streamUrl != null &&
          currentSong?.id != _loadedSong?.id) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _loadSong(currentSong!));
      }

      return Scaffold(
        appBar: AppBar(title: const Text('Player')),
        body: currentSong == null
            ? _buildLibrary(provider)
            : _buildNowPlaying(currentSong, provider),
      );
    });
  }

  Widget _buildNowPlaying(Song song, AppProvider provider) {
    return Column(
      children: [
        // Artwork
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: song.artworkUrl != null
                  ? Image.network(
                      song.artworkUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ArtPlaceholder(),
                    )
                  : _ArtPlaceholder(),
            ),
          ),
        ),

        // Song info
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                song.artist,
                style: const TextStyle(color: Colors.white60, fontSize: 16),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Progress bar
        StreamBuilder<Duration>(
          stream: _player.positionStream,
          builder: (context, snapshot) {
            final position = snapshot.data ?? Duration.zero;
            final duration = _player.duration ?? Duration.zero;
            final progress = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: AppTheme.radarGlow,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (v) {
                        final pos = Duration(
                          milliseconds: (v * duration.inMilliseconds).round(),
                        );
                        _player.seek(pos);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(position),
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        Text(_formatDuration(duration),
                            style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 40),
                onPressed: () {},
              ),
              StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) {
                  final playing = snapshot.data?.playing ?? false;
                  return GestureDetector(
                    onTap: playing ? _player.pause : _player.play,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.radarInner,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.radarInner.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.all(18),
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 40),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLibrary(AppProvider provider) {
    final songs = provider.songs;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text(
                'Your Library',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                onPressed: provider.loadSongs,
              ),
            ],
          ),
        ),
        Expanded(
          child: songs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_music, size: 64, color: Colors.white12),
                      SizedBox(height: 16),
                      Text(
                        'No songs in library',
                        style: TextStyle(color: Colors.white38),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Configure your server in Settings\nand tap Refresh',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white24, fontSize: 13),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (context, i) => ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: songs[i].artworkUrl != null
                          ? Image.network(
                              songs[i].artworkUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                width: 48,
                                height: 48,
                                child: Icon(Icons.music_note, color: Colors.white24),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: const Color(0xFF1E293B),
                              child: const Icon(Icons.music_note,
                                  color: Colors.white24),
                            ),
                    ),
                    title: Text(songs[i].title,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(songs[i].artist,
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    onTap: () => provider.setCurrentSong(songs[i]),
                  ),
                ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ArtPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E293B),
      child: const Center(
        child: Icon(Icons.music_note, color: Colors.white12, size: 80),
      ),
    );
  }
}