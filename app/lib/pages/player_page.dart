import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../deck/geometry.dart';
import '../deck/label_layer.dart';
import '../deck/tape_deck.dart';
import '../playback/playback.dart';
import '../player/ambient_background.dart';
import '../player/controls.dart';
import '../ui/style.dart';

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

const double _maxDeckWidth = 1200;

/// Vertical space reserved for the controls and hint under the deck.
const double _chromeHeight = 250;

/// Shown on the label before anything is threaded.
const Episode _blank = Episode(show: 'tinycast', tag: '', title: 'No tape threaded');

/// The tape deck.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  static const String route = '/player';

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  bool get _desktop => Platform.isMacOS;

  Playback get _playback => AppScope.of(context).playback;

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    if (file == null || !mounted) return;
    final path = file.path;
    await _playback.playFile(path != null ? AudioSource.file(path) : AudioSource.uri(file.uri), file.name);
  }

  Future<void> _dropFiles(List<DropItem> files) async {
    final file = files.where(_isAudio).firstOrNull;
    if (file == null) return;
    // A file dropped from outside the macOS sandbox needs security-scoped
    // access for as long as it plays.
    final bookmark = file.extraAppleBookmark;
    VoidCallback? release;
    if (bookmark != null && bookmark.isNotEmpty) {
      await DesktopDrop.instance.startAccessingSecurityScopedResource(bookmark: bookmark);
      release = () => unawaited(DesktopDrop.instance.stopAccessingSecurityScopedResource(bookmark: bookmark));
    }
    if (!mounted) return release?.call();
    await _playback.playFile(AudioSource.file(file.path), file.name, release: release);
  }

  static bool _isAudio(DropItem f) {
    if (f.mimeType?.startsWith('audio/') ?? false) return true;
    final dot = f.name.lastIndexOf('.');
    return dot >= 0 && _audioExtensions.contains(f.name.substring(dot + 1).toLowerCase());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final transport = _playback.transport;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (e is KeyDownEvent) transport.toggle();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      transport.skip(-15);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      transport.skip(30);
    } else if (key == LogicalKeyboardKey.escape) {
      if (e is KeyDownEvent) Navigator.of(context).maybePop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final playback = _playback;
    final transport = playback.transport;
    final hint = _desktop
        ? 'Space  play / pause    ·    ← →  skip    ·    drop an audio file on the deck'
        : 'Tap the label to load an episode';
    final canPop = Navigator.of(context).canPop();
    return CupertinoPageScaffold(
      backgroundColor: stage,
      child: GlassPage(
        background: AmbientBackground(transport: transport),
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    const gutter = 32.0;
                    // Fit the deck to the window, leaving room for the controls.
                    final room = constraints.maxWidth - 2 * gutter;
                    final fit = math.min(room, (constraints.maxHeight - _chromeHeight) * viewW / viewH);
                    final width = math.max(math.min(_maxDeckWidth, fit), math.min(room, 320.0));
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: gutter),
                          child: Center(
                            child: SizedBox(
                              width: width,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListenableBuilder(
                                    listenable: playback,
                                    builder: (context, _) => TapeDeck(
                                      transport: transport,
                                      episode: playback.current?.label ?? _blank,
                                      onPickFile: _pickFile,
                                      onDropFiles: _dropFiles,
                                      acceptsDrops: _desktop,
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 820),
                                    child: PlayerControls(transport: transport, onLoad: _pickFile),
                                  ),
                                  const SizedBox(height: 26),
                                  ListenableBuilder(
                                    listenable: Listenable.merge([playback, transport]),
                                    builder: (context, _) => Text(
                                      playback.error ?? (transport.buffering ? 'Buffering…' : hint),
                                      textAlign: TextAlign.center,
                                      style: textStyle(
                                        size: 12,
                                        spacing: 0.3,
                                        color: playback.error != null ? const Color(0xFFFF8A7A) : inkAt(0.38),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                if (canPop)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: ExcludeFocus(
                      child: GlassIconButton(
                        key: const Key('close-player'),
                        icon: Icon(CupertinoIcons.chevron_down, color: ink, size: 20),
                        semanticLabel: 'Close player',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
