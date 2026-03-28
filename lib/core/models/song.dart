class Song {
  final int id;
  final String title;
  final String artist;
  final String? album;
  final String? albumArtUrl;
  final String? spotifyPreviewUrl;
  final String? spotifyUrl;
  final int? durationMs;
  final String? spotifyTrackId;
  final bool? explicit;
  final String? releaseDate;
  final String? albumType;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.albumArtUrl,
    this.spotifyPreviewUrl,
    this.spotifyUrl,
    this.durationMs,
    this.spotifyTrackId,
    this.explicit,
    this.releaseDate,
    this.albumType,
  });

  String? get artworkUrl => albumArtUrl;
  String? get streamUrl => spotifyPreviewUrl;

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? json['name'] as String? ?? 'Unknown Title',
        artist: json['artist'] as String? ?? json['artistName'] as String? ?? 'Unknown Artist',
        album: json['album'] as String? ?? json['albumName'] as String?,
        albumArtUrl: json['albumArtUrl'] as String?,
        spotifyPreviewUrl: json['spotifyPreviewUrl'] as String? ?? json['previewUrl'] as String?,
        spotifyUrl: json['spotifyUrl'] as String?,
        durationMs: (json['durationMs'] as num?)?.toInt(),
        spotifyTrackId: json['spotifyTrackId'] as String?,
        explicit: json['explicit'] as bool?,
        releaseDate: json['releaseDate'] as String?,
        albumType: json['albumType'] as String?,
      );
}

/// A song that was recognized via audio capture.
/// Can be constructed from a /recognize response (flat + confidence)
/// or a /recognition-history item (nested song object).
class RecognizedSong extends Song {
  final DateTime recognizedAt;
  final double confidence;
  final int historyId;

  const RecognizedSong({
    required super.id,
    required super.title,
    required super.artist,
    super.album,
    super.albumArtUrl,
    super.spotifyPreviewUrl,
    super.spotifyUrl,
    super.durationMs,
    super.spotifyTrackId,
    super.explicit,
    super.releaseDate,
    super.albumType,
    required this.recognizedAt,
    this.confidence = 1.0,
    this.historyId = 0,
  });

  /// From POST /recognize response: { recognized, confidence, song: {...} }
  factory RecognizedSong.fromRecognizeJson(Map<String, dynamic> json) {
    final songJson = json['song'] as Map<String, dynamic>? ?? json;
    final base = Song.fromJson(songJson);
    return RecognizedSong(
      id: base.id,
      title: base.title,
      artist: base.artist,
      album: base.album,
      albumArtUrl: base.albumArtUrl,
      spotifyPreviewUrl: base.spotifyPreviewUrl,
      spotifyUrl: base.spotifyUrl,
      durationMs: base.durationMs,
      spotifyTrackId: base.spotifyTrackId,
      explicit: base.explicit,
      releaseDate: base.releaseDate,
      albumType: base.albumType,
      recognizedAt: DateTime.now(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// From GET /recognition-history item: { id, confidence, recognizedAt, song: {...} }
  factory RecognizedSong.fromHistoryJson(Map<String, dynamic> json) {
    final songJson = json['song'] as Map<String, dynamic>? ?? json;
    final base = Song.fromJson(songJson);
    return RecognizedSong(
      id: base.id,
      title: base.title,
      artist: base.artist,
      album: base.album,
      albumArtUrl: base.albumArtUrl,
      spotifyPreviewUrl: base.spotifyPreviewUrl,
      spotifyUrl: base.spotifyUrl,
      durationMs: base.durationMs,
      spotifyTrackId: base.spotifyTrackId,
      explicit: base.explicit,
      releaseDate: base.releaseDate,
      albumType: base.albumType,
      recognizedAt: json['recognizedAt'] != null
          ? DateTime.parse(json['recognizedAt'] as String)
          : DateTime.now(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      historyId: (json['id'] as num?)?.toInt() ?? 0,
    );
  }
}