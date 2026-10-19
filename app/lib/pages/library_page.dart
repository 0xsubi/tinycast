import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../library/downloads.dart';
import '../library/library.dart';
import '../playback/playback.dart';
import '../ui/chrome.dart';
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
    return GlassPageFrame(
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) => ListView(
          children: [
            PageHeading(
              title: 'Library',
              trailing: canChooseDownloadFolder
                  ? GlassIconButton(
                      key: const Key('settings'),
                      icon: Icon(CupertinoIcons.gear_alt, color: ink, size: 20),
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
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: const LiquidRoundedSuperellipse(borderRadius: 20),
          child: Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 16),
              Expanded(
                child: Text(label, style: textStyle(size: 17, weight: FontWeight.w600)),
              ),
              if (count > 0) ...[Text('$count', style: textStyle(size: 15, alpha: 0.45)), const SizedBox(width: 10)],
              Icon(CupertinoIcons.chevron_right, color: inkAt(0.35), size: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The shows the user subscribes to, as a grid.
class LibraryPodcastsPage extends StatelessWidget {
  const LibraryPodcastsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return GlassPageFrame(
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
    return GlassPageFrame(
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
Future<void> showSettings(BuildContext context) => GlassDialog.show<void>(
  context: context,
  title: 'Downloads',
  maxWidth: 380,
  content: _DownloadFolderSetting(downloads: AppScope.of(context).downloads),
  actions: [
    GlassDialogAction(
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
          style: textStyle(size: 14, weight: FontWeight.w600, color: accent),
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
