import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../library/downloads.dart';
import '../playback/playback.dart';
import '../podcast/format.dart';
import '../podcast/models.dart';
import '../ui/chrome.dart';
import '../ui/style.dart';

/// One episode: artwork, metadata and show notes, with Play, favorite and
/// download. Play threads it onto the deck.
class EpisodePage extends StatelessWidget {
  const EpisodePage({super.key, required this.podcast, required this.episode});

  /// The show, with its artwork and author filled in from the feed.
  final Podcast podcast;
  final PodcastEpisode episode;

  String? get _artwork => episode.artwork ?? podcast.artwork;

  void _play(BuildContext context) {
    final scope = AppScope.of(context);
    scope.playback.playEpisode(podcast, episode, file: scope.downloads.localFile(podcast, episode));
    openPlayer(context);
  }

  @override
  Widget build(BuildContext context) {
    final e = episode;
    final pills = [
      if (e.published != null) MetaPill(formatDate(e.published!), icon: CupertinoIcons.calendar),
      if (e.duration != null) MetaPill(formatLength(e.duration!), icon: CupertinoIcons.clock),
      if (e.season != null) MetaPill('Season ${e.season}'),
      if (e.number != null) MetaPill('Episode ${e.number}'),
      if (e.type == 'trailer') const MetaPill('Trailer'),
      if (e.type == 'bonus') const MetaPill('Bonus'),
      if (e.explicit ?? false) const MetaPill('Explicit'),
      if (e.bytes != null) MetaPill(formatBytes(e.bytes!), icon: CupertinoIcons.arrow_down_circle),
      if (_format(e.mimeType) case final format?) MetaPill(format),
    ];

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(podcast.title.toUpperCase(), style: eyebrow(color: accent)),
        const SizedBox(height: 8),
        Text(e.title, style: textStyle(size: 28, weight: FontWeight.w700, height: 1.18)),
        if (podcast.author case final author?) ...[
          const SizedBox(height: 6),
          Text(author, style: textStyle(size: 15, weight: FontWeight.w500, alpha: 0.6)),
        ],
        if (pills.isNotEmpty) ...[const SizedBox(height: 16), Wrap(spacing: 8, runSpacing: 8, children: pills)],
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _PlayButton(podcast: podcast, episode: e, onPlay: () => _play(context)),
            _FavoriteButton(podcast: podcast, episode: e),
            _DownloadButton(podcast: podcast, episode: e),
          ],
        ),
        _DownloadStatus(podcast: podcast, episode: e),
      ],
    );

    final notes = e.description == null
        ? const <Widget>[]
        : [
            const SizedBox(height: 34),
            Text('EPISODE NOTES', style: eyebrow()),
            const SizedBox(height: 10),
            SelectableText(e.description!, style: textStyle(size: 15, alpha: 0.78, height: 1.6)),
          ];

    return GlassPageFrame(
      artwork: _artwork,
      title: podcast.title,
      body: SingleChildScrollView(
        child: ContentColumn(
          child: Padding(
            padding: EdgeInsets.only(top: appBarClearance(context), bottom: bottomClearance(context)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Artwork(key: const Key('episode-art'), url: _artwork, size: 300, radius: 24),
                          const SizedBox(width: 36),
                          Expanded(child: heading),
                        ],
                      )
                    else ...[
                      Center(
                        child: Artwork(
                          key: const Key('episode-art'),
                          url: _artwork,
                          size: constraints.maxWidth.clamp(0, 300).toDouble(),
                          radius: 24,
                        ),
                      ),
                      const SizedBox(height: 28),
                      heading,
                    ],
                    ...notes,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// "MP3" from `audio/mpeg`.
String? _format(String? mime) => switch (mime?.toLowerCase()) {
  'audio/mpeg' || 'audio/mp3' => 'MP3',
  'audio/mp4' || 'audio/x-m4a' || 'audio/m4a' => 'AAC',
  'audio/aac' => 'AAC',
  'audio/ogg' || 'audio/opus' => 'Ogg',
  'audio/wav' || 'audio/x-wav' => 'WAV',
  'audio/flac' => 'FLAC',
  'video/mp4' => 'Video',
  _ => null,
};

/// The orange Play pill. Says "Resume" / "Open player" when this episode is
/// already on the deck.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.podcast, required this.episode, required this.onPlay});

  final Podcast podcast;
  final PodcastEpisode episode;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final playback = AppScope.of(context).playback;
    return ListenableBuilder(
      listenable: Listenable.merge([playback, playback.transport]),
      builder: (context, _) {
        final loaded = playback.current?.episode?.id == episode.id && playback.current?.podcast == podcast;
        final (icon, label) = !loaded
            ? (CupertinoIcons.play_fill, 'Play')
            : playback.transport.playing
            ? (CupertinoIcons.waveform, 'Now playing')
            : (CupertinoIcons.play_fill, 'Resume');
        return GlassButton.custom(
          key: const Key('play-episode'),
          onTap: onPlay,
          height: 52,
          shape: const LiquidRoundedSuperellipse(borderRadius: 26),
          settings: accentGlass,
          glowColor: accent.withValues(alpha: 0.5),
          stretch: 0.25,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: ink, size: 20),
                const SizedBox(width: 10),
                Text(label, style: textStyle(size: 16, weight: FontWeight.w600, alpha: 1)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.podcast, required this.episode});

  final Podcast podcast;
  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final on = library.isFavorite(podcast, episode);
        return GlassIconButton(
          key: const Key('favorite'),
          size: 52,
          icon: Icon(on ? CupertinoIcons.heart_fill : CupertinoIcons.heart, color: on ? accent : ink, size: 22),
          semanticLabel: on ? 'Remove from favorites' : 'Add to favorites',
          onPressed: () => on ? library.unfavorite(podcast, episode) : library.favorite(podcast, episode),
        );
      },
    );
  }
}

/// Download, then progress (tap to cancel), then a filled icon (tap to delete).
class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.podcast, required this.episode});

  final Podcast podcast;
  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context) {
    final downloads = AppScope.of(context).downloads;
    return ListenableBuilder(
      listenable: Listenable.merge([downloads, downloads.library]),
      builder: (context, _) {
        if (downloads.isDownloading(podcast, episode)) {
          final progress = downloads.progress(podcast, episode);
          return GlassButton.custom(
            key: const Key('download-cancel'),
            onTap: () => downloads.cancel(podcast, episode),
            height: 52,
            shape: const LiquidRoundedSuperellipse(borderRadius: 26),
            stretch: 0.25,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlassProgressIndicator.circular(value: progress, size: 18, color: accent),
                  const SizedBox(width: 10),
                  TabularText(
                    progress == null ? 'Downloading' : '${(progress * 100).floor()}%',
                    style: textStyle(size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 10),
                  Icon(CupertinoIcons.xmark, size: 14, color: inkAt(0.6)),
                ],
              ),
            ),
          );
        }
        final downloaded = downloads.localFile(podcast, episode) != null;
        return GlassIconButton(
          key: Key(downloaded ? 'delete-download' : 'download'),
          size: 52,
          icon: Icon(
            downloaded ? CupertinoIcons.arrow_down_circle_fill : CupertinoIcons.arrow_down_to_line,
            color: downloaded ? accent : ink,
            size: 22,
          ),
          semanticLabel: downloaded ? 'Delete download' : 'Download',
          onPressed: () =>
              downloaded ? confirmDeleteDownload(context, podcast, episode) : downloads.start(podcast, episode),
        );
      },
    );
  }
}

/// Asks before deleting a downloaded episode from disk.
Future<void> confirmDeleteDownload(BuildContext context, Podcast podcast, PodcastEpisode episode) {
  final downloads = AppScope.of(context).downloads;
  return GlassDialog.show<void>(
    context: context,
    title: 'Delete download?',
    message: '“${episode.title}” will be removed from this device. You can still stream it.',
    actions: [
      GlassDialogAction(label: 'Cancel', onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
      GlassDialogAction(
        label: 'Delete',
        isDestructive: true,
        onPressed: () {
          Navigator.of(context, rootNavigator: true).pop();
          downloads.delete(podcast, episode);
        },
      ),
    ],
  );
}

/// Where the download lives (with Show in Finder / Delete), or why it failed.
class _DownloadStatus extends StatelessWidget {
  const _DownloadStatus({required this.podcast, required this.episode});

  final Podcast podcast;
  final PodcastEpisode episode;

  @override
  Widget build(BuildContext context) {
    final downloads = AppScope.of(context).downloads;
    return ListenableBuilder(
      listenable: Listenable.merge([downloads, downloads.library]),
      builder: (context, _) {
        final error = downloads.error(podcast, episode);
        final path = downloads.isDownloading(podcast, episode)
            ? null
            : downloads.library.downloadPath(podcast, episode);
        if (error == null && path == null) return const SizedBox.shrink();
        Widget link(String label, Key key, VoidCallback onTap) => GestureDetector(
          key: key,
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              label,
              style: textStyle(size: 13, weight: FontWeight.w600, color: accent),
            ),
          ),
        );
        return Padding(
          padding: const EdgeInsets.only(top: 14),
          child: error != null
              ? Text(error, style: textStyle(size: 13, color: const Color(0xFFFF8A7A)))
              : Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      // Android keeps downloads out of sight, so there is no path to show.
                      canChooseDownloadFolder ? 'Downloaded to ${prettyPath(path!)}' : 'Downloaded',
                      style: textStyle(size: 13, alpha: 0.55),
                    ),
                    if (Platform.isMacOS)
                      link('Show in Finder', const Key('reveal-download'), () => downloads.reveal(podcast, episode)),
                    link(
                      'Delete',
                      const Key('delete-download-link'),
                      () => confirmDeleteDownload(context, podcast, episode),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
