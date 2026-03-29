import 'package:flutter/foundation.dart';
import 'package:spotify_sdk/spotify_sdk.dart';
import 'package:spotify_sdk/models/player_state.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

enum SpotifyPlaybackState { disconnected, connecting, connected, error }

class SpotifyPlaybackService {
  SpotifyPlaybackState _state = SpotifyPlaybackState.disconnected;
  SpotifyPlaybackState get state => _state;
  bool get isConnected => _state == SpotifyPlaybackState.connected;

  Future<bool> connect(String clientId, String redirectUrl) async {
    _state = SpotifyPlaybackState.connecting;
    try {
      final connected = await SpotifySdk.connectToSpotifyRemote(
        clientId: clientId,
        redirectUrl: redirectUrl,
      );
      _state = connected
          ? SpotifyPlaybackState.connected
          : SpotifyPlaybackState.error;
      return connected;
    } catch (e) {
      debugPrint('Spotify connect error: $e');
      _state = SpotifyPlaybackState.error;
      return false;
    }
  }

  Future<bool> playTrack(String trackId) async {
    try {
      await SpotifySdk.play(spotifyUri: 'spotify:track:$trackId');
      return true;
    } catch (e) {
      debugPrint('Spotify play error: $e');
      _state = SpotifyPlaybackState.disconnected;
      return false;
    }
  }

  Future<void> pause() async {
    try {
      await SpotifySdk.pause();
    } catch (_) {}
  }

  Future<void> resume() async {
    try {
      await SpotifySdk.resume();
    } catch (_) {}
  }

  Future<void> seekTo(int positionMs) async {
    try {
      await SpotifySdk.seekTo(positionedMilliseconds: positionMs);
    } catch (_) {}
  }

  Stream<PlayerState> get playerStateStream {
    try {
      return SpotifySdk.subscribePlayerState();
    } catch (_) {
      return const Stream.empty();
    }
  }

  // ── Static helpers ─────────────────────────────────────────────────────────

  /// Opens a Spotify entity in the Spotify app, falling back to web URL.
  /// [type] is 'track', 'playlist', or 'album'.
  static Future<void> openInSpotify({
    required String type,
    String? spotifyId,
    String? webUrl,
  }) async {
    // Try Spotify deep link first (opens Spotify app if installed)
    if (spotifyId != null && spotifyId.isNotEmpty) {
      try {
        final launched = await launchUrl(
          Uri.parse('spotify:$type:$spotifyId'),
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {}
    }
    // Fallback to web URL
    if (webUrl != null && webUrl.isNotEmpty) {
      try {
        await launchUrl(
          Uri.parse(webUrl),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
    }
  }
}