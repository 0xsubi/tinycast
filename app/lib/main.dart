import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'deck/paint_kit.dart';
import 'deck/textures.dart';
import 'library/downloads.dart';
import 'library/library.dart';
import 'pages/search_page.dart';
import 'playback/playback.dart';
import 'podcast/directory.dart';
import 'ui/style.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (library, _, _) = await (
    Library.open(),
    Textures.load(),
    LiquidGlassWidgets.initialize(enablePerformanceMonitor: false),
  ).wait;
  runApp(
    LiquidGlassWidgets.wrap(
      brightnessResolver: Theme.maybeBrightnessOf,
      child: ReelPlayerApp(library: library),
    ),
  );
}

class ReelPlayerApp extends StatefulWidget {
  const ReelPlayerApp({super.key, required this.library, this.downloads, this.directory, this.playback, this.home});

  /// The user's saved shows, episodes and settings.
  final Library library;

  /// Overrides for tests; the app uses the Apple Podcasts directory and a fresh deck.
  final Downloads? downloads;
  final PodcastDirectory? directory;
  final Playback? playback;
  final Widget? home;

  @override
  State<ReelPlayerApp> createState() => _ReelPlayerAppState();
}

class _ReelPlayerAppState extends State<ReelPlayerApp> {
  late final PodcastDirectory _directory = widget.directory ?? ITunesDirectory();
  late final Playback _playback = widget.playback ?? Playback();
  late final Downloads _downloads = widget.downloads ?? Downloads(widget.library);

  @override
  void dispose() {
    if (widget.playback == null) _playback.dispose();
    if (widget.downloads == null) _downloads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      playback: _playback,
      directory: _directory,
      library: widget.library,
      downloads: _downloads,
      child: MaterialApp(
        title: 'tinycast',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: urbanist,
          scaffoldBackgroundColor: stage,
          colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark, primary: accent),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: accent,
            selectionColor: accent.withValues(alpha: 0.35),
          ),
        ),
        // Every route gets a Material ancestor for text styles and selection.
        builder: (context, child) => Material(type: MaterialType.transparency, child: child),
        home: widget.home ?? const SearchPage(),
      ),
    );
  }
}
