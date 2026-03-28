import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/song.dart';

/// Uploads WAV audio chunks to the recognition server and parses the response.
///
/// Expected server contract:
///   POST {serverUrl}/recognize
///   Content-Type: multipart/form-data
///   Field: "audio" → .wav file bytes
///
///   Response JSON:
///   {
///     "recognized": true,
///     "song": { "id": "...", "title": "...", "artist": "...", ... }
///   }
class UploadService {
  final String serverUrl;
  final String recognizePath;

  UploadService({required this.serverUrl, required this.recognizePath});

  Future<RecognizedSong?> recognizeChunk(Uint8List wavBytes) async {
    final uri = Uri.parse('$serverUrl$recognizePath');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(http.MultipartFile.fromBytes(
        'audio',
        wavBytes,
        filename: 'capture_${DateTime.now().millisecondsSinceEpoch}.wav',
      ));

    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode != 200) return null;

    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['recognized'] != true) return null;

    final songJson = json['song'] as Map<String, dynamic>?;
    if (songJson == null) return null;

    return RecognizedSong.fromJson({
      ...songJson,
      'recognized_at': DateTime.now().toIso8601String(),
      'confidence': json['confidence'],
    });
  }

  Future<List<Song>> fetchSongs(String songsPath) async {
    final uri = Uri.parse('$serverUrl$songsPath');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];

    final json = jsonDecode(response.body);
    final list = json is List ? json : (json['songs'] as List? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .toList();
  }
}