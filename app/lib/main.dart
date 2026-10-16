import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import 'deck/controls_layer.dart';
import 'deck/paint_kit.dart';
import 'deck/tape_deck.dart';
import 'deck/textures.dart';
import 'deck/transport.dart';

const Episode _demoEpisode = Episode(show: 'Reel Talk', number: '042', title: 'The Warmth of Analog');
const double _demoDuration = 47 * 60 + 32;
// Resume part-way in, so both reels carry tape like the reference.
const double _demoResumeAt = 9 * 60 + 24;

const Set<String> _audioExtensions = {
  'mp3',
  'm4a',
  'm4b',
  'aac',
  'wav',
  'aif',
  'aiff',
  'flac',
  'ogg',
  'oga',
  'opus',
  'caf',
  'wma',
  'webm',
};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Textures.load();
  runApp(const ReelPlayerApp());
}

class ReelPlayerApp extends StatelessWidget {
  const ReelPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reel Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: rgb(0x0a0a0a)),
      home: const PlayerScreen(),
    );
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final Transport _transport = Transport(_demoDuration, startAt: _demoResumeAt);
  Episode _episode = _demoEpisode;
  String? _error;

  /// Security-scoped access to a file dropped from outside the macOS sandbox.
  Uint8List? _bookmark;

  bool get _desktop => Platform.isMacOS;

  @override
  void dispose() {
    _releaseBookmark();
    _transport.dispose();
    super.dispose();
  }

  Future<void> _load(AudioSource source, String name) async {
    setState(() => _error = null);
    try {
      await _transport.load(source);
      if (!mounted) return;
      setState(() {
        _episode = Episode(show: 'Local File', number: '001', title: name.replaceFirst(RegExp(r'\.[^.]+$'), ''));
      });
      _transport.play();
    } on LoadError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    if (file == null) return;
    final path = file.path;
    _releaseBookmark();
    await _load(path != null ? AudioSource.file(path) : AudioSource.uri(file.uri), file.name);
  }

  Future<void> _dropFiles(List<DropItem> files) async {
    final file = files.where(_isAudio).firstOrNull;
    if (file == null) return;
    _releaseBookmark();
    final bookmark = file.extraAppleBookmark;
    if (bookmark != null && bookmark.isNotEmpty) {
      await DesktopDrop.instance.startAccessingSecurityScopedResource(bookmark: bookmark);
      _bookmark = bookmark;
    }
    await _load(AudioSource.file(file.path), file.name);
  }

  void _releaseBookmark() {
    final b = _bookmark;
    _bookmark = null;
    if (b != null) unawaited(DesktopDrop.instance.stopAccessingSecurityScopedResource(bookmark: b));
  }

  static bool _isAudio(DropItem f) {
    if (f.mimeType?.startsWith('audio/') ?? false) return true;
    final dot = f.name.lastIndexOf('.');
    return dot >= 0 && _audioExtensions.contains(f.name.substring(dot + 1).toLowerCase());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (e is KeyDownEvent) _transport.toggle();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _transport.skip(-15);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _transport.skip(30);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final hint = _desktop
        ? 'Space play / pause · ← → skip · drop an audio file on the deck or click the label to load an episode'
        : 'Tap the label to load an episode';
    return Scaffold(
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: CustomPaint(
          painter: const _StageBackground(),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TapeDeck(
                          transport: _transport,
                          episode: _episode,
                          onPickFile: _pickFile,
                          onDropFiles: _dropFiles,
                          acceptsDrops: _desktop,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          _error ?? hint,
                          textAlign: TextAlign.center,
                          // CSS `line-height: normal` for Helvetica Neue.
                          style: helvetica(
                            size: 13,
                            weight: FontWeight.w400,
                            spacing: 13 * 0.04,
                            color: rgb(0x6f6f6f),
                          ).copyWith(height: 1.19),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `radial-gradient(ellipse at 50% 35%, #2a2a2a 0%, #151515 55%, #0a0a0a 100%)`
class _StageBackground extends CustomPainter {
  const _StageBackground();

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width * 0.5, size.height * 0.35);
    // CSS farthest-corner ellipse: the farthest-side ellipse scaled by √2.
    final rx = size.width * 0.5 * 1.41421356;
    final ry = size.height * 0.65 * 1.41421356;
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..scale(1, ry / rx)
      ..drawCircle(
        Offset.zero,
        // Big enough to cover the whole stage once squashed.
        rx * 4,
        shaded(userRadial(Offset.zero, rx, [(0, rgb(0x2a2a2a)), (0.55, rgb(0x151515)), (1, rgb(0x0a0a0a))])),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_StageBackground oldDelegate) => false;
}
