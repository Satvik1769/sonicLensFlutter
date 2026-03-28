import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/song.dart';
import '../../core/providers/app_provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final history = provider.history;

      return Scaffold(
        appBar: AppBar(title: const Text('Recognized Songs')),
        body: history.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: history.length,
                itemBuilder: (context, i) =>
                    _SongTile(song: history[i], provider: provider),
              ),
      );
    });
  }
}

class _SongTile extends StatelessWidget {
  final RecognizedSong song;
  final AppProvider provider;

  const _SongTile({required this.song, required this.provider});

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTime(song.recognizedAt);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: song.artworkUrl != null
            ? Image.network(
                song.artworkUrl!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _artPlaceholder(),
              )
            : _artPlaceholder(),
      ),
      title: Text(
        song.title,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${song.artist} • $timeAgo',
        style: const TextStyle(color: Colors.white54, fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: song.streamUrl != null
          ? IconButton(
              icon: const Icon(Icons.play_circle_outline, color: Colors.white54),
              onPressed: () => provider.setCurrentSong(song),
            )
          : null,
      onTap: song.streamUrl != null ? () => provider.setCurrentSong(song) : null,
    );
  }

  Widget _artPlaceholder() => Container(
        width: 52,
        height: 52,
        color: const Color(0xFF1E293B),
        child: const Icon(Icons.music_note, color: Colors.white24, size: 24),
      );

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.white12),
          SizedBox(height: 16),
          Text(
            'No songs recognized yet',
            style: TextStyle(color: Colors.white38, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Start listening from the Home tab',
            style: TextStyle(color: Colors.white24, fontSize: 13),
          ),
        ],
      ),
    );
  }
}