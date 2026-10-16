import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../playback/playback.dart';
import '../podcast/format.dart';
import '../podcast/models.dart';
import '../ui/chrome.dart';
import '../ui/style.dart';
import 'episode_page.dart';
import 'search_page.dart' show SliverCrossAxisConstrained;

/// A show: its artwork, description and episodes.
class PodcastPage extends StatefulWidget {
  const PodcastPage({super.key, required this.podcast});

  final Podcast podcast;

  @override
  State<PodcastPage> createState() => _PodcastPageState();
}

class _PodcastPageState extends State<PodcastPage> {
  late Future<PodcastFeed> _feed;
  bool _newestFirst = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feed = AppScope.of(context).directory.feed(widget.podcast);
  }

  void _retry() => setState(() => _feed = AppScope.of(context).directory.feed(widget.podcast));

  @override
  Widget build(BuildContext context) {
    final podcast = widget.podcast;
    return FutureBuilder<PodcastFeed>(
      future: _feed,
      builder: (context, snap) {
        final feed = snap.data;
        // Fill in what the directory listing lacked from the feed itself.
        final show = feed == null ? podcast : podcast.withFeed(feed);
        final artwork = show.artwork;
        return GlassPageFrame(
          artwork: artwork,
          title: podcast.title,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ContentColumn(
                  child: Padding(
                    padding: EdgeInsets.only(top: appBarClearance(context), bottom: 28),
                    child: _Header(podcast: show, feed: feed, artwork: artwork),
                  ),
                ),
              ),
              if (feed != null)
                ..._episodes(show, feed, artwork)
              else
                SliverToBoxAdapter(
                  child: snap.hasError
                      ? StateMessage(
                          text: '${snap.error}',
                          icon: CupertinoIcons.wifi_exclamationmark,
                          action: GlassButton.custom(
                            onTap: _retry,
                            width: 120,
                            height: 40,
                            shape: const LiquidRoundedSuperellipse(borderRadius: 20),
                            child: Text('Try again', style: textStyle(size: 14, weight: FontWeight.w600)),
                          ),
                        )
                      : const StateMessage(text: 'Loading episodes…', loading: true),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: nowPlayingClearance)),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _episodes(Podcast podcast, PodcastFeed feed, String? artwork) {
    if (feed.episodes.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: StateMessage(text: 'No playable episodes yet', icon: CupertinoIcons.waveform),
        ),
      ];
    }
    final episodes = sortEpisodes(feed.episodes, newestFirst: _newestFirst);
    return [
      SliverToBoxAdapter(
        child: ContentColumn(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: Text('${feed.episodes.length} EPISODES', style: eyebrow())),
                SizedBox(
                  width: 200,
                  child: GlassSegmentedControl(
                    key: const Key('sort'),
                    height: 34,
                    segments: const [
                      GlassSegment(label: 'Newest'),
                      GlassSegment(label: 'Oldest'),
                    ],
                    selectedIndex: _newestFirst ? 0 : 1,
                    selectedTextStyle: textStyle(size: 13, weight: FontWeight.w600, alpha: 1),
                    unselectedTextStyle: textStyle(size: 13, weight: FontWeight.w500, alpha: 0.6),
                    onSegmentSelected: (i) => setState(() => _newestFirst = i == 0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverCrossAxisConstrained(
          maxCrossAxisExtent: contentWidth - 40,
          child: SliverList.separated(
            itemCount: episodes.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final episode = episodes[i];
              return EpisodeCard(
                podcast: podcast,
                episode: episode,
                artwork: episode.artwork ?? artwork,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => EpisodePage(podcast: podcast, episode: episode),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }
}

/// [episodes] ordered by release date. Undated episodes keep their feed order
/// and go last.
List<PodcastEpisode> sortEpisodes(List<PodcastEpisode> episodes, {required bool newestFirst}) {
  final indexed = episodes.indexed.toList();
  indexed.sort((a, b) {
    final (ia, ea) = a;
    final (ib, eb) = b;
    final da = ea.published;
    final db = eb.published;
    if (da == null || db == null) {
      if (da != db) return da == null ? 1 : -1;
      return ia.compareTo(ib);
    }
    final byDate = newestFirst ? db.compareTo(da) : da.compareTo(db);
    return byDate != 0 ? byDate : ia.compareTo(ib);
  });
  return [for (final (_, e) in indexed) e];
}

class _Header extends StatelessWidget {
  const _Header({required this.podcast, required this.feed, required this.artwork});

  final Podcast podcast;
  final PodcastFeed? feed;
  final String? artwork;

  @override
  Widget build(BuildContext context) {
    final f = feed;
    final author = podcast.author;
    final pills = [
      if (podcast.genre != null) MetaPill(podcast.genre!, icon: CupertinoIcons.tag),
      if (f != null) MetaPill('${f.episodes.length} episodes', icon: CupertinoIcons.waveform),
      if (f?.episodes.firstOrNull?.published case final latest?)
        MetaPill('Updated ${formatDate(latest)}', icon: CupertinoIcons.calendar),
      if (f?.explicit ?? false) const MetaPill('Explicit'),
    ];
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PODCAST', style: eyebrow(color: accent)),
        const SizedBox(height: 6),
        Text(podcast.title, style: textStyle(size: 30, weight: FontWeight.w700, height: 1.15)),
        if (author != null) ...[
          const SizedBox(height: 6),
          Text(author, style: textStyle(size: 15, weight: FontWeight.w500, alpha: 0.65)),
        ],
        if (pills.isNotEmpty) ...[const SizedBox(height: 14), Wrap(spacing: 8, runSpacing: 8, children: pills)],
        const SizedBox(height: 18),
        _SubscribeButton(podcast: podcast),
        if (f?.description case final description?) ...[
          const SizedBox(height: 16),
          ExpandableText(description, maxLines: 4),
        ],
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Artwork(url: artwork, size: 180),
              const SizedBox(height: 20),
              details,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(url: artwork, size: 220),
            const SizedBox(width: 28),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _SubscribeButton extends StatelessWidget {
  const _SubscribeButton({required this.podcast});

  final Podcast podcast;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final subscribed = library.isSubscribed(podcast);
        return GlassButton.custom(
          key: const Key('subscribe'),
          onTap: () => subscribed ? library.unsubscribe(podcast) : library.subscribe(podcast),
          height: 44,
          shape: const LiquidRoundedSuperellipse(borderRadius: 22),
          settings: subscribed ? null : accentGlass,
          glowColor: subscribed ? null : accent.withValues(alpha: 0.5),
          stretch: 0.25,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(subscribed ? CupertinoIcons.checkmark_alt : CupertinoIcons.add, color: ink, size: 18),
                const SizedBox(width: 8),
                Text(
                  subscribed ? 'Subscribed' : 'Subscribe',
                  style: textStyle(size: 15, weight: FontWeight.w600, alpha: 1),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One row in an episode list. The description is cut short with an ellipsis
/// when it does not fit. Shows whether the episode is a favorite or downloaded.
class EpisodeCard extends StatelessWidget {
  const EpisodeCard({
    super.key,
    required this.podcast,
    required this.episode,
    required this.artwork,
    required this.onTap,
    this.showPodcast = false,
    this.trailing,
  });

  final Podcast podcast;
  final PodcastEpisode episode;
  final String? artwork;
  final VoidCallback onTap;

  /// Name the show above the title (for lists that mix shows).
  final bool showPodcast;

  /// Replaces the chevron.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (episode.published != null) formatDate(episode.published!),
      if (episode.duration != null) formatLength(episode.duration!),
      if (episode.type == 'trailer' || episode.type == 'bonus') episode.type!,
    ].join(' · ').toUpperCase();
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GlassCard(
          padding: const EdgeInsets.all(12),
          shape: const LiquidRoundedSuperellipse(borderRadius: 20),
          child: Row(
            children: [
              Artwork(url: artwork, size: 72, radius: 12, shadow: false),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showPodcast)
                      Text(
                        podcast.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: eyebrow(color: accent),
                      ),
                    Row(
                      children: [
                        if (meta.isNotEmpty) Flexible(child: Text(meta, maxLines: 1, style: eyebrow())),
                        _Badges(podcast: podcast, episode: episode),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      episode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle(size: 15, weight: FontWeight.w600, height: 1.25),
                    ),
                    if (episode.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        // Show notes run long; the card only has room for a taste.
                        episode.description!.replaceAll(RegExp(r'\s+'), ' '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle(size: 13, alpha: 0.55),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              trailing ?? Icon(CupertinoIcons.chevron_right, color: inkAt(0.35), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small heart / download marks next to an episode's date.
class _Badges extends StatelessWidget {
  const _Badges({required this.podcast, required this.episode});

  final Podcast podcast;
  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final saved = library.saved(podcast, episode);
        if (saved == null) return const SizedBox.shrink();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (saved.isFavorite) ...[
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.heart_fill, size: 12, color: accent, semanticLabel: 'Favorite'),
            ],
            if (saved.isDownloaded) ...[
              const SizedBox(width: 6),
              Icon(CupertinoIcons.arrow_down_circle_fill, size: 12, color: inkAt(0.6), semanticLabel: 'Downloaded'),
            ],
          ],
        );
      },
    );
  }
}

/// Text clamped to [maxLines] with a "More" toggle when it overflows.
class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text, {super.key, this.maxLines = 4});

  final String text;
  final int maxLines;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final style = textStyle(size: 14, alpha: 0.72, height: 1.5);
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = tp.didExceedMaxLines;
        tp.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              maxLines: _open ? null : widget.maxLines,
              overflow: _open ? null : TextOverflow.ellipsis,
              style: style,
            ),
            if (overflows)
              GestureDetector(
                onTap: () => setState(() => _open = !_open),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _open ? 'Less' : 'More',
                      style: textStyle(size: 14, weight: FontWeight.w600, color: accent),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
