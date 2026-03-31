import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/song.dart';
import '../models/trending.dart';

/// Central API service. All endpoints are built from [baseUrl].
/// Pass [authToken] for authenticated requests.
class ApiService {
  final String baseUrl;
  final String? authToken;

  const ApiService({required this.baseUrl, this.authToken});

  Map<String, String> get _authHeader =>
      authToken != null ? {'Authorization': 'Bearer $authToken'} : {};

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// Returns the JWT token on success, null on failure.
  Future<String?> login(String username, String password) async {
    try {
      final res = await http
          .post(
            _uri('/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      return json['token'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Returns true if registration succeeded.
  Future<bool> register(String username, String password, String email) async {
    try {
      final res = await http
          .post(
            _uri('/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password, 'email' : email }),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  // ── Recognition ───────────────────────────────────────────────────────────

  Future<RecognizedSong?> recognizeChunk(Uint8List wavBytes) async {
    final request = http.MultipartRequest('POST', _uri('/recognize'))
      ..headers.addAll(_authHeader)
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        wavBytes,
        filename: 'capture_${DateTime.now().millisecondsSinceEpoch}.wav',
        contentType: MediaType('audio', 'wav'),
      ));

    final streamed =
        await request.send().timeout(const Duration(seconds: 30));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) return null;

    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['recognized'] != true) return null;
    return RecognizedSong.fromRecognizeJson(json);
  }

  // ── Songs ─────────────────────────────────────────────────────────────────

  Future<List<Song>> fetchSongs() async {
    try {
      final res = await http
          .get(_uri('/songs'), headers: _authHeader)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      return _parseSongList(jsonDecode(res.body));
    } catch (_) {
      return [];
    }
  }

  Future<List<Song>> searchSongs(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final res = await http
          .get(
            _uri('/songs/search?q=${Uri.encodeQueryComponent(query.trim())}'),
            headers: _authHeader,
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      return _parseSongList(jsonDecode(res.body));
    } catch (_) {
      return [];
    }
  }

  // ── History ───────────────────────────────────────────────────────────────

  Future<List<RecognizedSong>> fetchHistory() async {
    try {
      final res = await http
          .get(_uri('/history'), headers: _authHeader)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return [];
      final json = jsonDecode(res.body);
      final list = json is List
          ? json
          : (json['content'] as List? ?? json['history'] as List? ?? []);
      return list
          .whereType<Map<String, dynamic>>()
          .map(RecognizedSong.fromHistoryJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Trending ──────────────────────────────────────────────────────────────

  Future<TrendingResponse?> fetchTrending() async {
    try {
      final res = await http
          .get(_uri('/trending'), headers: _authHeader)
          .timeout(const Duration(seconds: 60));
      if (res.statusCode != 200) return null;
      return TrendingResponse.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<Song> _parseSongList(dynamic json) {
    final list = json is List
        ? json
        : (json['content'] as List? ?? json['songs'] as List? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Song.fromJson)
        .toList();
  }
}