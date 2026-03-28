
class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? artworkUrl;
  final String? streamUrl;
  final int? durationSeconds;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.artworkUrl,
    this.streamUrl,
    this.durationSeconds,
  });

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id']?.toString() ?? '',
        title: json['title'] ?? 'Unknown Title',
        artist: json['artist'] ?? 'Unknown Artist',
        album: json['album'] ?? '',
        artworkUrl: json['artwork_url'] ?? json['artworkUrl'],
        streamUrl: json['stream_url'] ?? json['streamUrl'],
        durationSeconds: json['duration_seconds'] ?? json['durationSeconds'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        if (artworkUrl != null) 'artwork_url': artworkUrl,
        if (streamUrl != null) 'stream_url': streamUrl,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
      };
}

class RecognizedSong extends Song {
  final DateTime recognizedAt;
  final double confidence;

  const RecognizedSong({
    required super.id,
    required super.title,
    required super.artist,
    required super.album,
    super.artworkUrl,
    super.streamUrl,
    super.durationSeconds,
    required this.recognizedAt,
    this.confidence = 1.0,
  });

  factory RecognizedSong.fromJson(Map<String, dynamic> json) {
    final base = Song.fromJson(json);
    return RecognizedSong(
      id: base.id,
      title: base.title,
      artist: base.artist,
      album: base.album,
      artworkUrl: base.artworkUrl,
      streamUrl: base.streamUrl,
      durationSeconds: base.durationSeconds,
      recognizedAt: json['recognized_at'] != null
          ? DateTime.parse(json['recognized_at'])
          : DateTime.now(),
      confidence: (json['confidence'] ?? 1.0).toDouble(),
    );
  }
}