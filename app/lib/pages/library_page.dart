import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

import '../library/downloads.dart';
import '../library/library.dart';
import '../playback/playback.dart';
import '../ui/chrome.dart';
import '../ui/metal_ui.dart';
import '../ui/sections.dart';
import '../ui/style.dart';
import 'episode_page.dart';
import 'podcast_page.dart';

/// Library: the user's shows, favorites and downloads, each a page of its own.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    void push(Widget page) => Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
    return PageFrame(
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) => ListView(
          children: [
            PageHeading(
              title: 'Library',
              trailing: canChooseDownloadFolder
                  ? MetalIconButton(
                      key: const Key('settings'),
                      icon: CupertinoIcons.gear_alt,
                      semanticLabel: 'Settings',
                      onPressed: () => showSettings(context),
                    )
                  : null,
            ),
            ContentColumn(
              child: Column(
                children: [
                  _MenuRow(
                    key: const Key('library-podcasts'),
                    icon: CupertinoIcons.square_stack_3d_up,
                    label: 'Podcasts',
                    count: library.subscriptions.length,
                    onTap: () => push(const LibraryPodcastsPage()),
                  ),
                  _MenuRow(
                    key: const Key('library-favorites'),
                    icon: CupertinoIcons.heart,
                    label: 'Favorites',
                    count: library.favorites.length,
                    onTap: () => push(const FavoritesPage()),
                  ),
                  _MenuRow(
                    key: const Key('library-downloads'),
                    icon: CupertinoIcons.arrow_down_circle,
                    label: 'Downloads',
                    count: library.downloaded.length,
                    onTap: () => push(const DownloadsPage()),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ANOTHER DEVICE', style: eyebrow()),
                    ),
                  ),
                  _MenuRow(
                    key: const Key('export-library'),
                    icon: CupertinoIcons.square_arrow_up,
                    label: 'Export library',
                    count: 0,
                    onTap: () => exportLibrary(context),
                  ),
                  _MenuRow(
                    key: const Key('import-library'),
                    icon: CupertinoIcons.square_arrow_down,
                    label: 'Import library',
                    count: 0,
                    onTap: () => importLibrary(context),
                  ),
                ],
              ),
            ),
            SizedBox(height: bottomClearance(context)),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({super.key, required this.icon, required this.label, required this.count, required this.onTap});

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: MetalPlate(
      onTap: onTap,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Text(label, style: textStyle(size: 17, weight: FontWeight.w600)),
          ),
          if (count > 0) ...[Text('$count', style: textStyle(size: 15, alpha: 0.45)), const SizedBox(width: 10)],
          Icon(CupertinoIcons.chevron_right, color: inkAt(0.4), size: 16),
        ],
      ),
    ),
  );
}

/// Saves the library's shows, favorites and listening positions to a file
/// the user chooses, to import on another device.
Future<void> exportLibrary(BuildContext context) async {
  final library = AppScope.of(context).library;
  final json = const JsonEncoder.withIndent('  ').convert(library.export());
  final day = DateTime.now().toIso8601String().substring(0, 10);
  try {
    await FilePicker.saveFile(
      dialogTitle: 'Export library',
      fileName: 'tinycast-library-$day.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
      mimeType: 'application/json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
  } on Object catch (e) {
    if (context.mounted) await _tell(context, 'Could not export', '$e');
  }
}

/// Merges a library exported from another device into this one, then says
/// what it brought in.
Future<void> importLibrary(BuildContext context) async {
  final library = AppScope.of(context).library;
  final file = await FilePicker.pickFile(
    dialogTitle: 'Import library',
    type: FileType.custom,
    allowedExtensions: const ['json'],
  );
  if (file == null) return;
  String message;
  try {
    final text = utf8.decode(await file.readAsBytes());
    final Object? data;
    try {
      data = jsonDecode(text);
    } on FormatException {
      throw const FormatException('Not a tinycast library file');
    }
    message = importSummary(await library.import(data));
  } on FormatException catch (e) {
    message = e.message;
  } on Object catch (e) {
    message = 'Could not read that file: $e';
  }
  if (context.mounted) await _tell(context, 'Import library', message);
}

/// "Added 2 shows, 1 favorite and 5 listening positions."
String importSummary(LibraryImport result) {
  if (result.isEmpty) return 'Already up to date: this device has everything in that file.';
  String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  final parts = [
    if (result.subscriptions > 0) count(result.subscriptions, 'show', 'shows'),
    if (result.favorites > 0) count(result.favorites, 'favorite', 'favorites'),
    if (result.progress > 0) count(result.progress, 'listening position', 'listening positions'),
  ];
  final list = parts.length == 1 ? parts.single : '${parts.sublist(0, parts.length - 1).join(', ')} and ${parts.last}';
  return 'Added $list.';
}

Future<void> _tell(BuildContext context, String title, String message) => showMetalDialog<void>(
  context: context,
  title: title,
  message: message,
  actions: [
    MetalDialogAction(label: 'OK', isPrimary: true, onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
  ],
);

/// The shows the user subscribes to, as a grid.
class LibraryPodcastsPage extends StatelessWidget {
  const LibraryPodcastsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return PageFrame(
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final shows = library.subscriptions;
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: PageHeading(title: 'Podcasts', eyebrowText: 'LIBRARY'),
              ),
              if (shows.isEmpty)
                const SliverToBoxAdapter(
                  child: StateMessage(
                    text: 'Shows you subscribe to will appear here.',
                    icon: CupertinoIcons.square_stack_3d_up,
                  ),
                )
              else
                ShowGrid(
                  key: const Key('library-shows'),
                  shows: shows,
                  onOpen: (podcast) =>
                      Navigator.of(context)
                          .push(CupertinoPageRoute<void>(builder: (_) => PodcastPage(podcast: podcast))),
                ),
              SliverToBoxAdapter(child: SizedBox(height: bottomClearance(context))),
            ],
          );
        },
      ),
    );
  }
}

/// Favorited episodes, each removable from the list.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return _EpisodeList(
      title: 'Favorites',
      empty: 'Tap the heart on an episode to keep it here.',
      emptyIcon: CupertinoIcons.heart,
      keyPrefix: 'favorite',
      episodes: () => library.favorites,
      trailing: (saved) => GestureDetector(
        key: ValueKey('unfavorite-${saved.episode.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => library.unfavorite(saved.podcast, saved.episode),
        child: const MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Padding(
            padding: EdgeInsets.all(8),
            child: Icon(CupertinoIcons.heart_fill, color: accent, size: 20, semanticLabel: 'Remove from favorites'),
          ),
        ),
      ),
    );
  }
}

/// Downloaded episodes, newest download first.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return _EpisodeList(
      title: 'Downloads',
      empty: 'Episodes you download will appear here.',
      emptyIcon: CupertinoIcons.arrow_down_circle,
      keyPrefix: 'downloaded',
      episodes: () => library.downloaded,
    );
  }
}

/// A library page listing saved episodes; each opens without its feed.
class _EpisodeList extends StatelessWidget {
  const _EpisodeList({
    required this.title,
    required this.empty,
    required this.emptyIcon,
    required this.keyPrefix,
    required this.episodes,
    this.trailing,
  });

  final String title;
  final String empty;
  final IconData emptyIcon;
  final String keyPrefix;
  final List<SavedEpisode> Function() episodes;
  final Widget Function(SavedEpisode)? trailing;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return PageFrame(
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final saved = episodes();
          return ListView(
            children: [
              PageHeading(title: title, eyebrowText: 'LIBRARY'),
              if (saved.isEmpty)
                StateMessage(text: empty, icon: emptyIcon)
              else
                ContentColumn(
                  child: Column(
                    children: [
                      for (final s in saved)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: EpisodeCard(
                            key: ValueKey('$keyPrefix-${s.episode.id}'),
                            podcast: s.podcast,
                            episode: s.episode,
                            artwork: s.episode.artwork ?? s.podcast.artwork,
                            showPodcast: true,
                            onTap: () => Navigator.of(context).push(
                              CupertinoPageRoute<void>(
                                builder: (_) => EpisodePage(podcast: s.podcast, episode: s.episode),
                              ),
                            ),
                            trailing: trailing?.call(s),
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(height: bottomClearance(context)),
            ],
          );
        },
      ),
    );
  }
}

/// Settings: where downloads are saved (desktop only).
Future<void> showSettings(BuildContext context) => showMetalDialog<void>(
  context: context,
  title: 'Downloads',
  maxWidth: 380,
  content: _DownloadFolderSetting(downloads: AppScope.of(context).downloads),
  actions: [
    MetalDialogAction(
      label: 'Done',
      isPrimary: true,
      onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
    ),
  ],
);

class _DownloadFolderSetting extends StatelessWidget {
  const _DownloadFolderSetting({required this.downloads});

  final Downloads downloads;

  Future<void> _change() async {
    final current = await downloads.folder();
    // The picker can only open a folder that exists.
    await Directory(current).create(recursive: true);
    final picked = await FilePicker.getDirectoryPath(dialogTitle: 'Save downloads to', initialDirectory: current);
    if (picked != null) await downloads.setFolder(picked);
  }

  @override
  Widget build(BuildContext context) {
    Widget link(String label, Key key, VoidCallback onTap) => GestureDetector(
      key: key,
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          label,
          style: textStyle(size: 14, weight: FontWeight.w600, color: accentInk),
        ),
      ),
    );
    return ListenableBuilder(
      listenable: downloads.library,
      builder: (context, _) => FutureBuilder<String>(
        future: downloads.folder(),
        builder: (context, snap) {
          final custom = downloads.library.setting(downloadFolderSetting) != null;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              children: [
                Text('New episodes are saved to', style: textStyle(size: 13, alpha: 0.6)),
                const SizedBox(height: 6),
                SelectableText(
                  snap.hasData ? prettyPath(snap.data!) : '…',
                  textAlign: TextAlign.center,
                  style: textStyle(size: 14, weight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    link('Change…', const Key('change-folder'), _change),
                    if (custom) link('Use default', const Key('reset-folder'), () => downloads.setFolder(null)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
