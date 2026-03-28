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
  final _searchController = TextEditingController();
  Song? _loadedSong;
  bool _loading = false;
  bool _showSearch = false;

  @override
  void dispose() {
    _player.dispose();
    _searchController.dispose();
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

  void _onSearchSubmit(String query, AppProvider provider) {
    if (query.trim().isNotEmpty) {
      provider.searchSongs(query.trim());
    } else {
      provider.clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final currentSong = provider.currentSong;

      if (currentSong?.streamUrl != null &&
          currentSong?.id != _loadedSong?.id) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _loadSong(currentSong!));
      }

      return Scaffold(
        appBar: AppBar(
          title: _showSearch
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search songs...',
                    hintStyle: TextStyle(color: Colors.white38),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (q) => _onSearchSubmit(q, provider),
                  onChanged: (q) {
                    if (q.isEmpty) provider.clearSearch();
                  },
                )
              : const Text('Player'),
          actions: [
            if (currentSong != null)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Back to library',
                onPressed: () {
                  _player.stop();
                  _loadedSong = null;
                  provider.setCurrentSong(null);
                },
              )
            else ...[
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() => _showSearch = !_showSearch);
                  if (!_showSearch) {
                    _searchController.clear();
                    provider.clearSearch();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: provider.loadSongs,
              ),
            ],
          ],
        ),
        body: currentSong == null
            ? _buildLibrary(provider)
            : _buildNowPlaying(currentSong, provider),
      );
    });
  }

  // ── Now Playing ───────────────────────────────────────────────────────────

  Widget _buildNowPlaying(Song song, AppProvider provider) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 32, 40, 0),
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
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [song.artist, if (song.album != null) song.album!]
                          .join(' · '),
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (song.releaseDate != null)
                      Text(
                        song.releaseDate!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (song.explicit == true)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'E',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildProgressBar(song),
        _buildControls(provider),
        const SizedBox(height: 8),
        if (song.spotifyUrl != null)
          TextButton.icon(
            icon: const Icon(Icons.open_in_new, size: 14, color: Colors.white38),
            label: const Text(
              'Open in Spotify',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            onPressed: () {}, // open URL via url_launcher if added
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProgressBar(Song song) {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = song.durationMs != null
            ? Duration(milliseconds: song.durationMs!)
            : (_player.duration ?? Duration.zero);
        final progress = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: AppTheme.radarGlow,
                  inactiveTrackColor: Colors.white12,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: progress,
                  onChanged: (v) => _player.seek(
                    Duration(milliseconds: (v * duration.inMilliseconds).round()),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(position),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    Text(_fmt(duration),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(AppProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded,
                color: Colors.white, size: 40),
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
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.skip_next_rounded,
                color: Colors.white, size: 40),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ── Library / Search ──────────────────────────────────────────────────────

  Widget _buildLibrary(AppProvider provider) {
    final isSearchActive =
        _showSearch && _searchController.text.trim().isNotEmpty;
    final displayList =
        isSearchActive ? provider.searchResults : provider.songs;

    if (provider.searching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearchActive ? Icons.search_off : Icons.library_music,
              size: 64,
              color: Colors.white12,
            ),
            const SizedBox(height: 16),
            Text(
              isSearchActive ? 'No results found' : 'No songs in library',
              style: const TextStyle(color: Colors.white38),
            ),
            if (!isSearchActive) ...[
              const SizedBox(height: 8),
              const Text(
                'Configure your server in Settings\nand tap Refresh',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white24, fontSize: 13),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: displayList.length,
      itemBuilder: (context, i) => _SongListTile(
        song: displayList[i],
        onTap: () => provider.setCurrentSong(displayList[i]),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _SongListTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongListTile({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final duration = song.durationMs != null
        ? _fmtMs(song.durationMs!)
        : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: song.artworkUrl != null
            ? Image.network(
                song.artworkUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
      ),
      title: Text(song.title,
          style: const TextStyle(color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [song.artist, if (song.album != null) song.album!].join(' · '),
        style: const TextStyle(color: Colors.white54, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: duration != null
          ? Text(duration,
              style: const TextStyle(color: Colors.white38, fontSize: 12))
          : null,
      onTap: song.streamUrl != null ? onTap : null,
    );
  }

  Widget _placeholder() => Container(
        width: 48,
        height: 48,
        color: const Color(0xFF1E293B),
        child: const Icon(Icons.music_note, color: Colors.white24),
      );

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
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