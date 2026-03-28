import 'song.dart';

class SpotifyTrack {
  final String spotifyId;
  final String name;
  final String artistName;
  final String? albumName;
  final String? albumArtUrl;
  final String? previewUrl;
  final int? durationMs;
  final String? spotifyUrl;
  final bool? explicit;
  final String? releaseDate;
  final String? albumType;

  const SpotifyTrack({
    required this.spotifyId,
    required this.name,
    required this.artistName,
    this.albumName,
    this.albumArtUrl,
    this.previewUrl,
    this.durationMs,
    this.spotifyUrl,
    this.explicit,
    this.releaseDate,
    this.albumType,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) => SpotifyTrack(
        spotifyId: json['spotifyId'] as String? ?? json['spotifyTrackId'] as String? ?? '',
        name: json['name'] as String? ?? json['title'] as String? ?? 'Unknown',
        artistName: json['artistName'] as String? ?? json['artist'] as String? ?? 'Unknown Artist',
        albumName: json['albumName'] as String? ?? json['album'] as String?,
        albumArtUrl: json['albumArtUrl'] as String?,
        previewUrl: json['previewUrl'] as String? ?? json['spotifyPreviewUrl'] as String?,
        durationMs: (json['durationMs'] as num?)?.toInt(),
        spotifyUrl: json['spotifyUrl'] as String?,
        explicit: json['explicit'] as bool?,
        releaseDate: json['releaseDate'] as String?,
        albumType: json['albumType'] as String?,
      );

  /// Convert to [Song] so the existing player can play it.
  Song toSong() => Song(
        id: spotifyId.hashCode,
        title: name,
        artist: artistName,
        album: albumName,
        albumArtUrl: albumArtUrl,
        spotifyPreviewUrl: previewUrl,
        spotifyUrl: spotifyUrl,
        durationMs: durationMs,
        explicit: explicit,
        releaseDate: releaseDate,
        albumType: albumType,
        spotifyTrackId: spotifyId,
      );
}

class SpotifyPlaylist {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final int totalTracks;
  final String? spotifyUrl;
  final String? owner;

  const SpotifyPlaylist({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.totalTracks,
    this.spotifyUrl,
    this.owner,
  });

  factory SpotifyPlaylist.fromJson(Map<String, dynamic> json) => SpotifyPlaylist(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown Playlist',
        description: json['description'] as String?,
        imageUrl: json['imageUrl'] as String?,
        totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
        spotifyUrl: json['spotifyUrl'] as String?,
        owner: json['owner'] as String?,
      );
}

class SpotifyAlbum {
  final String id;
  final String name;
  final String? artistName;
  final String? albumType;
  final String? releaseDate;
  final String? imageUrl;
  final int totalTracks;
  final String? spotifyUrl;

  const SpotifyAlbum({
    required this.id,
    required this.name,
    this.artistName,
    this.albumType,
    this.releaseDate,
    this.imageUrl,
    required this.totalTracks,
    this.spotifyUrl,
  });

  factory SpotifyAlbum.fromJson(Map<String, dynamic> json) => SpotifyAlbum(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unknown Album',
        artistName: json['artistName'] as String?,
        albumType: json['albumType'] as String?,
        releaseDate: json['releaseDate'] as String?,
        imageUrl: json['imageUrl'] as String?,
        totalTracks: (json['totalTracks'] as num?)?.toInt() ?? 0,
        spotifyUrl: json['spotifyUrl'] as String?,
      );
}

class TrendingResponse {
  final List<SpotifyTrack> trendingTracks;
  final List<SpotifyPlaylist> trendingPlaylists;
  final List<SpotifyAlbum> newReleases;

  const TrendingResponse({
    required this.trendingTracks,
    required this.trendingPlaylists,
    required this.newReleases,
  });

  factory TrendingResponse.fromJson(Map<String, dynamic> json) =>
      TrendingResponse(
        trendingTracks: (json['trendingTracks'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SpotifyTrack.fromJson)
            .toList(),
        trendingPlaylists: (json['trendingPlaylists'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SpotifyPlaylist.fromJson)
            .toList(),
        newReleases: (json['newReleases'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(SpotifyAlbum.fromJson)
            .toList(),
      );

  bool get isEmpty =>
      trendingTracks.isEmpty &&
      trendingPlaylists.isEmpty &&
      newReleases.isEmpty;
}