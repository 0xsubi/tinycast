import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../deck/label_layer.dart';
import '../deck/tape_deck.dart';
import '../playback/playback.dart';
import '../player/metal_controls.dart';

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
    final canPop = Navigator.of(context).canPop();
    return CupertinoPageScaffold(
      child: GlassPage(
        child: Focus(
          autofocus: true,
          onKeyEvent: _onKey,
          child: MetalDevice(
            transport: transport,
            deck: (unit, upright) => ListenableBuilder(
              listenable: playback,
              builder: (context, _) => TapeDeck(
                transport: transport,
                episode: playback.current?.label ?? _blank,
                onPickFile: _pickFile,
                onDropFiles: _dropFiles,
                unit: unit,
                upright: upright,
                failed: playback.error != null,
                acceptsDrops: _desktop,
                leading: canPop
                    ? ExcludeFocus(
                        child: GlassIconButton(
                          key: const Key('close-player'),
                          size: bandButtonSize(unit),
                          icon: const Icon(CupertinoIcons.chevron_down, color: Color(0xFF333331), size: 20),
                          semanticLabel: 'Close player',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
