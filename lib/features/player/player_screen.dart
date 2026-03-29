import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../../core/models/song.dart';
import '../../core/models/trending.dart';
import '../../core/providers/app_provider.dart';
import '../../core/services/spotify_playback_service.dart';
import '../../core/theme/app_theme.dart';

enum _PlayMode { preview, none }

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  // Preview player (30-second clips)
  final _previewPlayer = AudioPlayer();
  Song? _loadedSong;
  bool _previewLoading = false;

  _PlayMode _playMode = _PlayMode.none;

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
    _previewPlayer.dispose();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Main entry point when user taps a track.
  Future<void> _onTrackTap(Song song, AppProvider provider) async {
    // Show the player immediately so UI doesn't feel unresponsive
    provider.setCurrentSong(song);

    final hasSpotifyId =
        song.spotifyTrackId != null && song.spotifyTrackId!.isNotEmpty;

    // Try 30-second preview URL (in-app playback)
    if (song.streamUrl != null) {
      if (mounted) setState(() => _playMode = _PlayMode.preview);
      await _loadPreview(song);
      return;
    }

    // No preview → open in Spotify app or browser
    if (hasSpotifyId || song.spotifyUrl != null) {
      await SpotifyPlaybackService.openInSpotify(
        type: 'track',
        spotifyId: song.spotifyTrackId,
        webUrl: song.spotifyUrl,
      );
    }
    if (mounted) setState(() => _playMode = _PlayMode.none);
  }

  Future<void> _loadPreview(Song song) async {
    if (_loadedSong?.id == song.id) return;
    setState(() => _previewLoading = true);
    try {
      await _previewPlayer.setUrl(song.streamUrl!);
      _loadedSong = song;
      await _previewPlayer.play();
    } catch (e) {
      debugPrint('Preview player error: $e');
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  void _stopAndClear(AppProvider provider) {
    if (_playMode == _PlayMode.preview) {
      _previewPlayer.stop();
      _loadedSong = null;
    }
    setState(() => _playMode = _PlayMode.none);
    provider.setCurrentSong(null);
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _openSearch() => setState(() => _searchActive = true);

  void _closeSearch() {
    setState(() {
      _searchActive = false;
      _searchCtrl.clear();
    });
    context.read<AppProvider>().clearSearch();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final currentSong = provider.currentSong;

      if (currentSong != null &&
          _playMode == _PlayMode.preview &&
          currentSong.streamUrl != null &&
          currentSong.id != _loadedSong?.id) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _loadPreview(currentSong));
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
          onPressed: () => _stopAndClear(provider),
        ),
        actions: [
          if (song.spotifyUrl != null)
            IconButton(
              icon: const _SpotifyIcon(),
              tooltip: 'Open in Spotify',
              onPressed: () => SpotifyPlaybackService.openInSpotify(
                type: 'track',
                spotifyId: song.spotifyTrackId,
                webUrl: song.spotifyUrl,
              ),
            ),
        ],
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
                if (song.explicit == true) _buildExplicitBadge(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_playMode == _PlayMode.preview)
            ...[_buildPreviewProgressBar(song), _buildPreviewControls()]
          else
            _buildOpenInSpotifyPrompt(song),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Preview controls ──────────────────────────────────────────────────────

  Widget _buildPreviewProgressBar(Song song) {
    return StreamBuilder<Duration>(
      stream: _previewPlayer.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = song.durationMs != null
            ? Duration(milliseconds: song.durationMs!)
            : (_previewPlayer.duration ?? Duration.zero);
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
                  value: progress.toDouble(),
                  onChanged: (v) => _previewPlayer.seek(Duration(
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
                    Row(
                      children: [
                        const Icon(Icons.preview_rounded,
                            size: 11, color: Colors.white24),
                        const SizedBox(width: 3),
                        Text(_fmt(duration),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPreviewControls() {
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
            stream: _previewPlayer.playerStateStream,
            builder: (context, snapshot) {
              final playing = snapshot.data?.playing ?? false;
              return GestureDetector(
                onTap: playing ? _previewPlayer.pause : _previewPlayer.play,
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
                  child: _previewLoading
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

  Widget _buildOpenInSpotifyPrompt(Song song) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: FilledButton.icon(
        icon: const _SpotifyIcon(size: 18, color: Colors.white),
        label: const Text('Open in Spotify'),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF1DB954),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => SpotifyPlaybackService.openInSpotify(
          type: 'track',
          spotifyId: song.spotifyTrackId,
          webUrl: song.spotifyUrl,
        ),
      ),
    );
  }

  Widget _buildExplicitBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(3),
        ),
        child: const Text('E',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  // ── Trending scaffold ─────────────────────────────────────────────────────

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
                          onPlay: (t) => _onTrackTap(t.toSong(), provider),
                        ),
                        _PlaylistsTab(
                          playlists: provider.trending!.trendingPlaylists,
                          onTap: (p) =>
                              _showPlaylistDetail(context, p),
                        ),
                        _AlbumsTab(
                          albums: provider.trending!.newReleases,
                          onTap: (a) => _showAlbumDetail(context, a),
                        ),
                      ],
                    ),
    );
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

  // ── Search body ───────────────────────────────────────────────────────────

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
          onTap: () {
            _closeSearch();
            _onTrackTap(song, provider);
          },
        );
      },
    );
  }

  // ── Detail sheets ─────────────────────────────────────────────────────────

  void _showPlaylistDetail(BuildContext context, SpotifyPlaylist playlist) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlaylistDetailSheet(playlist: playlist),
    );
  }

  void _showAlbumDetail(BuildContext context, SpotifyAlbum album) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AlbumDetailSheet(album: album),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
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
          onTap: () => onPlay(t),
        );
      },
    );
  }

  static String _fmtMs(int ms) {
    final d = Duration(milliseconds: ms);
    return '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}

// ── Playlists Tab ─────────────────────────────────────────────────────────────

class _PlaylistsTab extends StatelessWidget {
  final List<SpotifyPlaylist> playlists;
  final void Function(SpotifyPlaylist) onTap;

  const _PlaylistsTab({required this.playlists, required this.onTap});

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
      itemBuilder: (context, i) =>
          _PlaylistCard(playlist: playlists[i], onTap: onTap),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final SpotifyPlaylist playlist;
  final void Function(SpotifyPlaylist) onTap;
  const _PlaylistCard({required this.playlist, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(playlist),
      child: Container(
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
                        errorBuilder: (_, __, ___) =>
                            _gridPlaceholder(Icons.queue_music),
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
  final void Function(SpotifyAlbum) onTap;

  const _AlbumsTab({required this.albums, required this.onTap});

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
                    style: const TextStyle(
                        color: Colors.white60, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              Row(
                children: [
                  if (a.albumType != null)
                    Text(a.albumType!.toUpperCase(),
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                  if (a.albumType != null && a.releaseDate != null)
                    const Text(' · ',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 11)),
                  if (a.releaseDate != null)
                    Text(a.releaseDate!,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11)),
                ],
              ),
            ],
          ),
          isThreeLine: true,
          trailing: Text('${a.totalTracks} tracks',
              style: const TextStyle(color: Colors.white38, fontSize: 11)),
          onTap: () => onTap(a),
        );
      },
    );
  }
}

// ── Playlist Detail Sheet ─────────────────────────────────────────────────────

class _PlaylistDetailSheet extends StatelessWidget {
  final SpotifyPlaylist playlist;
  const _PlaylistDetailSheet({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                children: [
                  // Art + info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: playlist.imageUrl != null
                            ? Image.network(
                                playlist.imageUrl!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _detailPlaceholder(Icons.queue_music),
                              )
                            : _detailPlaceholder(Icons.queue_music),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(playlist.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            if (playlist.owner != null)
                              _metaRow(Icons.person_outline, playlist.owner!),
                            _metaRow(Icons.music_note,
                                '${playlist.totalTracks} tracks'),
                            if (playlist.description != null &&
                                playlist.description!.isNotEmpty)
                              _metaRow(Icons.info_outline,
                                  playlist.description!),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  // Open in Spotify
                  _SpotifyButton(
                    label: 'Open in Spotify',
                    onPressed: () => SpotifyPlaybackService.openInSpotify(
                      type: 'playlist',
                      spotifyId: playlist.id,
                      webUrl: playlist.spotifyUrl,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailPlaceholder(IconData icon) => Container(
        width: 120,
        height: 120,
        color: const Color(0xFF1E293B),
        child: Center(child: Icon(icon, color: Colors.white24, size: 48)),
      );

  Widget _metaRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ),
          ],
        ),
      );
}

// ── Album Detail Sheet ────────────────────────────────────────────────────────

class _AlbumDetailSheet extends StatelessWidget {
  final SpotifyAlbum album;
  const _AlbumDetailSheet({required this.album});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: album.imageUrl != null
                            ? Image.network(
                                album.imageUrl!,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _detailPlaceholder(Icons.album),
                              )
                            : _detailPlaceholder(Icons.album),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(album.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            if (album.artistName != null)
                              _metaRow(Icons.person_outline, album.artistName!),
                            if (album.albumType != null)
                              _metaRow(Icons.album_outlined,
                                  album.albumType!.toUpperCase()),
                            if (album.releaseDate != null)
                              _metaRow(Icons.calendar_today_outlined,
                                  album.releaseDate!),
                            _metaRow(Icons.music_note,
                                '${album.totalTracks} tracks'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  _SpotifyButton(
                    label: 'Open in Spotify',
                    onPressed: () => SpotifyPlaybackService.openInSpotify(
                      type: 'album',
                      spotifyId: album.id,
                      webUrl: album.spotifyUrl,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailPlaceholder(IconData icon) => Container(
        width: 120,
        height: 120,
        color: const Color(0xFF1E293B),
        child: Center(child: Icon(icon, color: Colors.white24, size: 48)),
      );

  Widget _metaRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ),
          ],
        ),
      );
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SpotifyButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _SpotifyButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: const _SpotifyIcon(size: 18, color: Colors.white),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1DB954),
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
    );
  }
}

class _SpotifyIcon extends StatelessWidget {
  final double size;
  final Color color;
  const _SpotifyIcon({this.size = 20, this.color = const Color(0xFF1DB954)});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.music_note_rounded, size: size, color: color);
  }
}

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
      child: const Center(
          child: Icon(Icons.music_note, color: Colors.white12, size: 80)),
    );
  }
}