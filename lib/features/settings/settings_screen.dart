import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _serverCtrl;
  late TextEditingController _recognizeCtrl;
  late TextEditingController _songsCtrl;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<AppProvider>();
    _serverCtrl = TextEditingController(text: p.serverUrl);
    _recognizeCtrl = TextEditingController(text: p.recognizePath);
    _songsCtrl = TextEditingController(text: p.songsPath);
  }

  @override
  void dispose() {
    _serverCtrl.dispose();
    _recognizeCtrl.dispose();
    _songsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final p = context.read<AppProvider>();
    await p.saveSettings(
      serverUrl: _serverCtrl.text.trim(),
      recognizePath: _recognizeCtrl.text.trim(),
      songsPath: _songsCtrl.text.trim(),
    );
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const _SectionHeader('Server Configuration'),
          const SizedBox(height: 8),
          const Text(
            'Point SonicLens at your recognition server. '
            'Every 20 seconds, a WAV audio chunk is uploaded to the recognize endpoint.',
            style: TextStyle(color: Colors.white54, fontSize: 13),
          ),
          const SizedBox(height: 20),
          _Field(
            controller: _serverCtrl,
            label: 'Server URL',
            hint: 'http://192.168.1.100:8000',
            icon: Icons.dns_outlined,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _recognizeCtrl,
            label: 'Recognize Endpoint',
            hint: '/recognize',
            icon: Icons.music_note_outlined,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: _songsCtrl,
            label: 'Songs Library Endpoint',
            hint: '/songs',
            icon: Icons.library_music_outlined,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_saved ? 'Saved!' : 'Save Settings'),
          ),
          const SizedBox(height: 40),
          const _SectionHeader('Server API Contract'),
          const SizedBox(height: 8),
          _CodeBlock('''
POST {serverUrl}/recognize
Content-Type: multipart/form-data
Field: "audio" → capture_xxxxx.wav

Response:
{
  "recognized": true,
  "confidence": 0.95,
  "song": {
    "id": "123",
    "title": "Song Name",
    "artist": "Artist",
    "album": "Album",
    "artwork_url": "http://...",
    "stream_url": "http://..."
  }
}'''),
          const SizedBox(height: 24),
          const _SectionHeader('About Shizuku'),
          const SizedBox(height: 8),
          const Text(
            'SonicLens uses Shizuku to capture all system audio without root. '
            'Install the Shizuku app, then start it via ADB or root.\n\n'
            'ADB command:\n  adb shell sh /sdcard/Android/data/moe.shizuku.privileged.api/start.sh',
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0D6EFD), width: 1.5),
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock(this.code);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Color(0xFF7DD3FC),
          fontSize: 12,
          fontFamily: 'monospace',
          height: 1.6,
        ),
      ),
    );
  }
}