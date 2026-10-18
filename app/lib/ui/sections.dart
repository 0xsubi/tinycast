import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../podcast/format.dart';
import '../podcast/models.dart';
import 'chrome.dart';
import 'style.dart';

/// The top of a tab or list page: a small eyebrow over a large title, with
/// room for a button on the right.
class PageHeading extends StatelessWidget {
  const PageHeading({super.key, required this.title, this.eyebrowText = 'TINYCAST', this.trailing, this.below});

  final String title;
  final String eyebrowText;
  final Widget? trailing;

  /// Under the title, e.g. a search bar.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return ContentColumn(
      child: Padding(
        padding: EdgeInsets.only(
          top: canPop ? appBarClearance(context) : MediaQuery.paddingOf(context).top + 44,
          bottom: 24,
        ),
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
                      Text(eyebrowText, style: eyebrow(color: accent)),
                      const SizedBox(height: 6),
                      Text(title, style: textStyle(size: 34, weight: FontWeight.w700, height: 1.1)),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (below != null) ...[const SizedBox(height: 20), below!],
          ],
        ),
      ),
    );
  }
}

/// A section's small uppercase label, with an optional link on the right.
Widget sectionHeading(String text, {Widget? trailing}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    children: [
      Expanded(child: Text(text, style: eyebrow())),
      ?trailing,
    ],
  ),
);

/// Quiet text standing in for an empty section.
Widget sectionHint(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 4),
  child: Text(text, style: textStyle(size: 13.5, alpha: 0.45)),
);

/// A small accent text button.
Widget textLink(String label, Key key, VoidCallback onTap) => GestureDetector(
  key: key,
  onTap: onTap,
  child: MouseRegion(
    cursor: SystemMouseCursors.click,
    child: Text(
      label,
      style: textStyle(size: 13.5, weight: FontWeight.w600, color: accent),
    ),
  ),
);

/// A horizontally scrolling row of cards, as wide as the content.
class CardRow extends StatelessWidget {
  const CardRow({
    super.key,
    required this.height,
    required this.width,
    required this.itemCount,
    required this.itemBuilder,
  });

  final double height;
  final double width;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentWidth),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) => SizedBox(width: width, child: itemBuilder(context, i)),
        ),
      ),
    ),
  );
}

/// Height of a [ShowRow].
const double showRowHeight = 262;

/// A row of [ShowCard]s.
class ShowRow extends StatelessWidget {
  const ShowRow({super.key, required this.shows, required this.onOpen});

  final List<Podcast> shows;
  final ValueChanged<Podcast> onOpen;

  @override
  Widget build(BuildContext context) => CardRow(
    height: showRowHeight,
    width: 176,
    itemCount: shows.length,
    itemBuilder: (context, i) => ShowCard(podcast: shows[i], onTap: () => onOpen(shows[i])),
  );
}

/// A grid of [ShowCard]s, as a sliver.
class ShowGrid extends StatelessWidget {
  const ShowGrid({super.key, required this.shows, required this.onOpen});

  final List<Podcast> shows;
  final ValueChanged<Podcast> onOpen;

  @override
  Widget build(BuildContext context) => SliverPadding(
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
        itemBuilder: (context, i) => ShowCard(podcast: shows[i], onTap: () => onOpen(shows[i])),
      ),
    ),
  );
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

/// A show's artwork, title and author.
class ShowCard extends StatelessWidget {
  const ShowCard({super.key, required this.podcast, required this.onTap});

  final Podcast podcast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _Tappable(
    onTap: onTap,
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
  );
}

/// Height of a row of [EpisodeTile]s.
const double episodeRowHeight = 318;

/// An episode as a card of its own: its artwork (the show's when it has
/// none), the show, the title and when it came out.
class EpisodeTile extends StatelessWidget {
  const EpisodeTile({super.key, required this.podcast, required this.episode, required this.onTap});

  final Podcast podcast;
  final PodcastEpisode episode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (episode.published != null) formatDate(episode.published!),
      if (episode.duration != null) formatLength(episode.duration!),
    ].join(' · ');
    return _Tappable(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(10),
        shape: const LiquidRoundedSuperellipse(borderRadius: 22),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Artwork(url: episode.artwork ?? podcast.artwork, size: constraints.maxWidth, radius: 14),
              const SizedBox(height: 10),
              Text(
                podcast.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: eyebrow(color: accent),
              ),
              const SizedBox(height: 4),
              Text(
                episode.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textStyle(size: 14, weight: FontWeight.w600, height: 1.25),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle(size: 12.5, alpha: 0.55)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: MouseRegion(cursor: SystemMouseCursors.click, child: child),
  );
}
