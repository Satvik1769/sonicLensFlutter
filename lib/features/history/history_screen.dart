import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/song.dart';
import '../../core/providers/app_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _loadedFromServer = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedFromServer) {
      _loadedFromServer = true;
      // Load server history once on first build if user is logged in
      final provider = context.read<AppProvider>();
      if (provider.isLoggedIn) provider.loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, provider, _) {
      final history = provider.history;

      return Scaffold(
        appBar: AppBar(
          title: const Text('History'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload from server',
              onPressed: provider.isLoggedIn ? provider.loadHistory : null,
            ),
          ],
        ),
        body: history.isEmpty
            ? const _EmptyState()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: history.length,
                itemBuilder: (context, i) =>
                    _HistoryTile(song: history[i], provider: provider),
              ),
      );
    });
  }
}

class _HistoryTile extends StatelessWidget {
  final RecognizedSong song;
  final AppProvider provider;
  const _HistoryTile({required this.song, required this.provider});

  @override
  Widget build(BuildContext context) {
    final confidencePct = (song.confidence * 100).round();
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
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            song.artist,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                timeAgo,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      isThreeLine: true,
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
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(8),
        ),
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

class _ConfidenceBadge extends StatelessWidget {
  final int confidence;
  const _ConfidenceBadge({required this.confidence});

  Color get _color {
    if (confidence >= 80) return Colors.greenAccent;
    if (confidence >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq, size: 10, color: _color),
          const SizedBox(width: 3),
          Text(
            '$confidence%',
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: _color),
          ),
        ],
      ),
    );
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