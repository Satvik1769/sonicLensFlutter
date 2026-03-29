import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;

/// Handles opening Spotify content in the Spotify app or browser.
class SpotifyPlaybackService {
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