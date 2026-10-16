import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../library/downloads.dart';
import '../playback/playback.dart';
import '../podcast/directory.dart';
import '../podcast/models.dart';
import '../ui/chrome.dart';
import '../ui/style.dart';
import 'episode_page.dart';
import 'podcast_page.dart';

/// Home: search the podcast directory.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _query = TextEditingController();
  Timer? _debounce;

  /// The search the results belong to; null before the first search.
  String? _term;
  Future<List<Podcast>>? _results;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _changed(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(text));
  }

  void _search(String text) {
    _debounce?.cancel();
    final term = text.trim();
    if (term == _term) return;
    setState(() {
      _term = term.isEmpty ? null : term;
      _results = term.isEmpty ? null : AppScope.of(context).directory.search(term);
    });
  }

  void _open(Podcast podcast) =>
      Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => PodcastPage(podcast: podcast)));

  @override
  Widget build(BuildContext context) {
    return GlassPageFrame(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ContentColumn(
              child: Padding(
                padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 44, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TINYCAST', style: eyebrow(color: accent)),
                              const SizedBox(height: 6),
                              Text('Find a show', style: textStyle(size: 34, weight: FontWeight.w700, height: 1.1)),
                            ],
                          ),
                        ),
                        if (canChooseDownloadFolder)
                          GlassIconButton(
                            key: const Key('settings'),
                            icon: Icon(CupertinoIcons.gear_alt, color: ink, size: 20),
                            semanticLabel: 'Settings',
                            onPressed: () => showSettings(context),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    GlassSearchBar(
                      key: const Key('search'),
                      controller: _query,
                      placeholder: 'Search podcasts',
                      onChanged: _changed,
                      onSubmitted: _search,
                      height: 48,
                      textStyle: textStyle(size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ..._body(),
          const SliverToBoxAdapter(child: SizedBox(height: nowPlayingClearance)),
        ],
      ),
    );
  }

  List<Widget> _body() {
    final results = _results;
    if (results == null) {
      return [
        SliverToBoxAdapter(
          child: ListenableBuilder(
            listenable: AppScope.of(context).library,
            builder: (context, _) => _Library(onOpen: _open),
          ),
        ),
      ];
    }
    return [
      FutureBuilder<List<Podcast>>(
        key: ValueKey(_term),
        future: results,
        builder: (context, snap) {
          Widget message(StateMessage m) => SliverToBoxAdapter(child: m);
          if (snap.connectionState != ConnectionState.done) {
            return message(const StateMessage(text: 'Searching…', loading: true));
          }
          if (snap.hasError) {
            return message(StateMessage(text: '${snap.error}', icon: CupertinoIcons.wifi_exclamationmark));
          }
          final shows = snap.data!;
          if (shows.isEmpty) {
            return message(StateMessage(text: 'No shows match “$_term”', icon: CupertinoIcons.search));
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverCrossAxisConstrained(
              maxCrossAxisExtent: contentWidth - 40,
              child: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 210,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.7,
                ),
                itemCount: shows.length,
                itemBuilder: (context, i) => _ShowCard(podcast: shows[i], onTap: () => _open(shows[i])),
              ),
            ),
          );
        },
      ),
    ];
  }
}

/// Caps a sliver's cross-axis extent and centres it, like [ContentColumn] for slivers.
class SliverCrossAxisConstrained extends StatelessWidget {
  const SliverCrossAxisConstrained({super.key, required this.maxCrossAxisExtent, required this.child});

  final double maxCrossAxisExtent;
  final Widget child;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final spare = constraints.crossAxisExtent - maxCrossAxisExtent;
      return SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: spare > 0 ? spare / 2 : 0),
        sliver: child,
      );
    },
  );
}

class _ShowCard extends StatelessWidget {
  const _ShowCard({required this.podcast, required this.onTap});

  final Podcast podcast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        shape: const LiquidRoundedSuperellipse(borderRadius: 22),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Artwork(url: podcast.artwork, size: constraints.maxWidth, radius: 14),
              const SizedBox(height: 10),
              Text(
                podcast.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textStyle(size: 14, weight: FontWeight.w600, height: 1.25),
              ),
              const SizedBox(height: 3),
              if (podcast.author != null)
                Text(
                  podcast.author!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle(size: 12.5, alpha: 0.55),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.podcast, required this.onTap});

  final Podcast podcast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const Key('featured'),
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        shape: const LiquidRoundedSuperellipse(borderRadius: 26),
        child: Row(
          children: [
            Artwork(url: podcast.artwork, size: 120, radius: 16),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    podcast.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle(size: 20, weight: FontWeight.w700, height: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text([podcast.author, podcast.genre].nonNulls.join(' · '), style: textStyle(size: 13.5, alpha: 0.6)),
                  const SizedBox(height: 12),
                  Text(
                    'Search millions of shows from the Apple Podcasts directory above.',
                    style: textStyle(size: 13, alpha: 0.45),
                  ),
                ],
              ),
            ),
            Icon(CupertinoIcons.chevron_right, color: inkAt(0.4), size: 18),
          ],
        ),
      ),
    ),
  );
}

/// The home page before a search: the user's shows and episodes, then a pick.
class _Library extends StatelessWidget {
  const _Library({required this.onOpen});

  final ValueChanged<Podcast> onOpen;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    final shows = library.subscriptions;
    final favorites = library.favorites;
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: eyebrow()),
    );
    Widget hint(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: textStyle(size: 13.5, alpha: 0.45)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContentColumn(child: heading('YOUR PODCASTS')),
        if (shows.isEmpty)
          ContentColumn(child: hint('Shows you subscribe to will appear here.'))
        else
          SizedBox(
            height: 262,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentWidth),
                child: ListView.separated(
                  key: const Key('your-podcasts'),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: shows.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, i) => SizedBox(
                    width: 176,
                    child: _ShowCard(podcast: shows[i], onTap: () => onOpen(shows[i])),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 30),
        ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading('YOUR EPISODES'),
              if (favorites.isEmpty)
                hint('Tap the heart on an episode to keep it here.')
              else
                for (final saved in favorites)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: EpisodeCard(
                      key: ValueKey('favorite-${saved.episode.id}'),
                      podcast: saved.podcast,
                      episode: saved.episode,
                      artwork: saved.episode.artwork ?? saved.podcast.artwork,
                      showPodcast: true,
                      onTap: () => Navigator.of(context).push(
                        CupertinoPageRoute<void>(
                          builder: (_) => EpisodePage(podcast: saved.podcast, episode: saved.episode),
                        ),
                      ),
                      trailing: GestureDetector(
                        key: ValueKey('unfavorite-${saved.episode.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => library.unfavorite(saved.podcast, saved.episode),
                        child: const MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              CupertinoIcons.heart_fill,
                              color: accent,
                              size: 20,
                              semanticLabel: 'Remove from favorites',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              const SizedBox(height: 30),
              heading('FEATURED'),
              _FeaturedCard(podcast: waveform, onTap: () => onOpen(waveform)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Settings: where downloads are saved (desktop only).
Future<void> showSettings(BuildContext context) => GlassDialog.show<void>(
  context: context,
  title: 'Downloads',
  maxWidth: 380,
  content: _DownloadFolderSetting(downloads: AppScope.of(context).downloads),
  actions: [GlassDialogAction(label: 'Done', isPrimary: true, onPressed: () => Navigator.of(context).pop())],
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
