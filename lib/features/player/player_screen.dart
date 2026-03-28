import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../core/models/song.dart';
import '../../core/models/trending.dart';
import '../../core/providers/app_provider.dart';
import '../../core/theme/app_theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  Song? _loadedSong;
  bool _loading = false;
  late TabController _tabController;

  bool _searchActive = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().loadTrending();
    });
  }

  @override
  void dispose() {
    _player.dispose();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openSearch() => setState(() => _searchActive = true);

  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchCtrl.clear();
    });
    context.read<AppProvider>().clearSearch();
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
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _loadSong(currentSong!));
      }

      if (currentSong != null) {
        return _buildNowPlayingScaffold(currentSong, provider);
      }

      return _buildTrendingScaffold(provider);
    });
  }

  // ── Now Playing ───────────────────────────────────────────────────────────

  Widget _buildNowPlayingScaffold(Song song, AppProvider provider) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _player.stop();
            _loadedSong = null;
            provider.setCurrentSong(null);
          },
        ),
      ),
      body: Column(
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
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 14),
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('E',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressBar(song),
          _buildControls(),
          const SizedBox(height: 32),
        ],
      ),
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
            ? (position.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0)
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
                  onChanged: (v) => _player.seek(Duration(
                      milliseconds: (v * duration.inMilliseconds).round())),
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

  Widget _buildControls() {
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

  // ── Trending ──────────────────────────────────────────────────────────────

  Widget _buildTrendingScaffold(AppProvider provider) {
    return Scaffold(
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: AppTheme.radarGlow,
                decoration: const InputDecoration(
                  hintText: 'Search songs…',
                  hintStyle: TextStyle(color: Colors.white38),
                  border: InputBorder.none,
                ),
                onChanged: (q) {
                  if (q.trim().isEmpty) {
                    provider.clearSearch();
                  } else {
                    provider.searchSongs(q.trim());
                  }
                },
              )
            : const Text('Player'),
        leading: _searchActive
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _closeSearch,
              )
            : null,
        bottom: _searchActive
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.radarGlow,
                labelColor: AppTheme.radarGlow,
                unselectedLabelColor: Colors.white38,
                tabs: const [
                  Tab(text: 'Tracks'),
                  Tab(text: 'Playlists'),
                  Tab(text: 'New Releases'),
                ],
              ),
        actions: [
          if (_searchActive)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _closeSearch,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _openSearch,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: provider.loadTrending,
            ),
          ],
        ],
      ),
      body: _searchActive
          ? _buildSearchBody(provider)
          : provider.loadingTrending
              ? const Center(child: CircularProgressIndicator())
              : provider.trending == null
                  ? _buildEmptyTrending(provider)
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _TracksTab(
                            tracks: provider.trending!.trendingTracks,
                            onPlay: (t) =>
                                provider.setCurrentSong(t.toSong())),
                        _PlaylistsTab(
                            playlists: provider.trending!.trendingPlaylists),
                        _AlbumsTab(albums: provider.trending!.newReleases),
                      ],
                    ),
    );
  }

  Widget _buildSearchBody(AppProvider provider) {
    if (provider.searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchCtrl.text.trim().isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 56, color: Colors.white12),
            SizedBox(height: 12),
            Text('Type to search songs',
                style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    if (provider.searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 56, color: Colors.white12),
            SizedBox(height: 12),
            Text('No results found',
                style: TextStyle(color: Colors.white38)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: provider.searchResults.length,
      itemBuilder: (context, i) {
        final song = provider.searchResults[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: _Thumb(url: song.artworkUrl),
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
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (song.explicit == true)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: _ExplicitBadge(),
                ),
              if (song.durationMs != null)
                Text(_fmtMs(song.durationMs!),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
            ],
          ),
          onTap: song.streamUrl != null
              ? () {
                  provider.setCurrentSong(song);
                  _closeSearch();
                }
              : null,
        );
      },
    );
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyTrending(AppProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.trending_up, size: 64, color: Colors.white12),
          const SizedBox(height: 16),
          const Text('Could not load trending',
              style: TextStyle(color: Colors.white38, fontSize: 16)),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Try again'),
            onPressed: provider.loadTrending,
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

// ── Tracks Tab ────────────────────────────────────────────────────────────────

class _TracksTab extends StatelessWidget {
  final List<SpotifyTrack> tracks;
  final void Function(SpotifyTrack) onPlay;

  const _TracksTab({required this.tracks, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const _EmptyTab(icon: Icons.music_note, label: 'No tracks');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final t = tracks[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: _Thumb(url: t.albumArtUrl),
          title: Text(t.name,
              style: const TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [t.artistName, if (t.albumName != null) t.albumName!].join(' · '),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (t.explicit == true)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: _ExplicitBadge(),
                ),
              if (t.durationMs != null)
                Text(_fmtMs(t.durationMs!),
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
            ],
          ),
          onTap: t.previewUrl != null ? () => onPlay(t) : null,
        );
      },
    );
  }

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}

// ── Playlists Tab ─────────────────────────────────────────────────────────────

class _PlaylistsTab extends StatelessWidget {
  final List<SpotifyPlaylist> playlists;
  const _PlaylistsTab({required this.playlists});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) {
      return const _EmptyTab(icon: Icons.queue_music, label: 'No playlists');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: playlists.length,
      itemBuilder: (context, i) => _PlaylistCard(playlist: playlists[i]),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final SpotifyPlaylist playlist;
  const _PlaylistCard({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: playlist.imageUrl != null
                  ? Image.network(
                      playlist.imageUrl!,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _gridPlaceholder(
                          Icons.queue_music),
                    )
                  : _gridPlaceholder(Icons.queue_music),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playlist.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${playlist.totalTracks} tracks'
                  '${playlist.owner != null ? ' · ${playlist.owner}' : ''}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridPlaceholder(IconData icon) => Container(
        color: const Color(0xFF0F172A),
        child: Center(child: Icon(icon, color: Colors.white12, size: 40)),
      );
}

// ── Albums Tab ────────────────────────────────────────────────────────────────

class _AlbumsTab extends StatelessWidget {
  final List<SpotifyAlbum> albums;
  const _AlbumsTab({required this.albums});

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const _EmptyTab(icon: Icons.album, label: 'No new releases');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: albums.length,
      itemBuilder: (context, i) {
        final a = albums[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: _Thumb(url: a.imageUrl, size: 52),
          title: Text(a.name,
              style: const TextStyle(color: Colors.white),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (a.artistName != null)
                Text(a.artistName!,
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              Row(
                children: [
                  if (a.albumType != null)
                    Text(
                      a.albumType!.toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  if (a.albumType != null && a.releaseDate != null)
                    const Text(' · ',
                        style: TextStyle(color: Colors.white24, fontSize: 11)),
                  if (a.releaseDate != null)
                    Text(a.releaseDate!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Text(
            '${a.totalTracks} tracks',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        );
      },
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _Thumb extends StatelessWidget {
  final String? url;
  final double size;
  const _Thumb({this.url, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: url != null
          ? Image.network(url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder())
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: const Color(0xFF1E293B),
        child: const Icon(Icons.music_note, color: Colors.white24, size: 20),
      );
}

class _ExplicitBadge extends StatelessWidget {
  const _ExplicitBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text('E',
          style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.white12),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }
}

class _ArtPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E293B),
      child:
          const Center(child: Icon(Icons.music_note, color: Colors.white12, size: 80)),
    );
  }
}