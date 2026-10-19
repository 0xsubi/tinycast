import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../playback/playback.dart';
import '../podcast/feed.dart';
import '../podcast/interests.dart';
import '../podcast/models.dart';
import '../ui/chrome.dart';
import '../ui/sections.dart';
import '../ui/style.dart';
import 'episode_page.dart';
import 'interests_page.dart';
import 'podcast_page.dart';

/// Most shows Latest Episodes lists an episode from.
const int _latestCount = 20;

/// Most episodes Continue lists.
const int _continueCount = 20;

/// Home: the newest episodes of the user's shows, the episodes they left
/// part-way, the shows themselves, then the top shows for each of their
/// interests.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    void open(Podcast podcast) =>
        Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => PodcastPage(podcast: podcast)));
    return GlassPageFrame(
      body: ListenableBuilder(
        listenable: library,
        builder: (context, _) {
          final shows = library.subscriptions;
          return ListView(
            children: [
              const PageHeading(title: 'Home'),
              // Keyed on the shows, so subscribing reloads it.
              _LatestEpisodes(key: ValueKey(shows.map((s) => s.feed).join('\n')), shows: shows),
              const _ContinueListening(),
              ContentColumn(child: sectionHeading('YOUR PODCASTS')),
              if (shows.isEmpty)
                ContentColumn(child: sectionHint('Shows you subscribe to will appear here.'))
              else
                ShowRow(key: const Key('your-podcasts'), shows: shows, onOpen: open),
              const SizedBox(height: 30),
              _ForYou(onOpen: open),
              SizedBox(height: bottomClearance(context)),
            ],
          );
        },
      ),
    );
  }
}

typedef _Latest = ({Podcast podcast, PodcastEpisode episode});

/// The newest episode of each of the user's shows, newest first, read from
/// their feeds.
class _LatestEpisodes extends StatefulWidget {
  const _LatestEpisodes({super.key, required this.shows});

  final List<Podcast> shows;

  @override
  State<_LatestEpisodes> createState() => _LatestEpisodesState();
}

class _LatestEpisodesState extends State<_LatestEpisodes> {
  late Future<List<_Latest>> _latest = _load();

  /// The directory keeps feeds for the session. A show whose feed can't be
  /// reached is left out; only when none can is it an error.
  Future<List<_Latest>> _load() async {
    final shows = widget.shows;
    if (shows.isEmpty) return const [];
    final directory = AppScope.of(context).directory;
    final feeds = await Future.wait([
      for (final show in shows) directory.feed(show).then<PodcastFeed?>((f) => f, onError: (Object _) => null),
    ]);
    if (feeds.every((f) => f == null)) throw const FeedError('Couldn’t reach your shows’ feeds');
    final epoch = DateTime.utc(0);
    DateTime published(PodcastEpisode e) => e.published ?? epoch;
    final latest = <_Latest>[
      for (final (i, feed) in feeds.indexed)
        if (feed != null && feed.episodes.isNotEmpty)
          (
            podcast: shows[i].withFeed(feed),
            // Feeds usually list newest first, but not all do.
            episode: feed.episodes.reduce((a, b) => published(b).isAfter(published(a)) ? b : a),
          ),
    ]..sort((a, b) => published(b.episode).compareTo(published(a.episode)));
    return latest.take(_latestCount).toList();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ContentColumn(child: sectionHeading('LATEST EPISODES')),
      FutureBuilder<List<_Latest>>(
        future: _latest,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const _RowLoading(height: episodeRowHeight);
          if (snap.hasError) {
            return ContentColumn(
              child: _Retry(
                message: '${snap.error}.',
                retryKey: const Key('retry-latest'),
                onRetry: () => setState(() => _latest = _load()),
              ),
            );
          }
          final latest = snap.data!;
          if (latest.isEmpty) {
            return ContentColumn(
              child: sectionHint(
                widget.shows.isEmpty
                    ? 'Subscribe to shows to see their newest episodes here.'
                    : 'Your shows haven’t published anything yet.',
              ),
            );
          }
          return CardRow(
            key: const Key('latest-episodes'),
            height: episodeRowHeight,
            width: 200,
            itemCount: latest.length,
            itemBuilder: (context, i) {
              final (:podcast, :episode) = latest[i];
              return EpisodeTile(
                key: ValueKey('latest-${episode.id}'),
                podcast: podcast,
                episode: episode,
                onTap: () => Navigator.of(context).push(
                  CupertinoPageRoute<void>(
                    builder: (_) => EpisodePage(podcast: podcast, episode: episode),
                  ),
                ),
              );
            },
          );
        },
      ),
      const SizedBox(height: 30),
    ],
  );
}

/// Episodes the user left part-way, most recently played first, with how much
/// of each they have heard. Absent while there are none.
class _ContinueListening extends StatelessWidget {
  const _ContinueListening();

  @override
  Widget build(BuildContext context) {
    final library = AppScope.of(context).library;
    return ListenableBuilder(
      listenable: library.progressChanges,
      builder: (context, _) {
        final listening = library.listening.take(_continueCount).toList();
        if (listening.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ContentColumn(child: sectionHeading('CONTINUE WHERE YOU LEFT OFF')),
            CardRow(
              key: const Key('continue-listening'),
              height: episodeRowHeight,
              width: 200,
              itemCount: listening.length,
              itemBuilder: (context, i) {
                final l = listening[i];
                return EpisodeTile(
                  key: ValueKey('continue-${l.episode.id}'),
                  podcast: l.podcast,
                  episode: l.episode,
                  listening: l,
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => EpisodePage(podcast: l.podcast, episode: l.episode),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ],
        );
      },
    );
  }
}

/// The top shows for each of the user's interests, or an invitation to pick some.
class _ForYou extends StatelessWidget {
  const _ForYou({required this.onOpen});

  final ValueChanged<Podcast> onOpen;

  void _edit(BuildContext context) =>
      Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => const InterestsPage()));

  @override
  Widget build(BuildContext context) {
    final interests = chosenInterests(AppScope.of(context).library) ?? const [];
    final edit = textLink(interests.isEmpty ? 'Choose' : 'Edit', const Key('edit-interests'), () => _edit(context));
    if (interests.isEmpty) {
      return ContentColumn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionHeading('FOR YOU', trailing: edit),
            sectionHint('Pick a few topics to see their top shows here.'),
            const SizedBox(height: 30),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, interest) in interests.indexed)
          _InterestRow(
            key: ValueKey('interest-row-${interest.genre}'),
            interest: interest,
            trailing: i == 0 ? edit : null,
            onOpen: onOpen,
          ),
      ],
    );
  }
}

/// One interest's heading and its top shows.
class _InterestRow extends StatefulWidget {
  const _InterestRow({super.key, required this.interest, required this.onOpen, this.trailing});

  final Interest interest;
  final ValueChanged<Podcast> onOpen;
  final Widget? trailing;

  @override
  State<_InterestRow> createState() => _InterestRowState();
}

class _InterestRowState extends State<_InterestRow> {
  late Future<List<Podcast>> _shows = _load();

  /// The directory keeps charts for the session, so this is cheap after the first time.
  Future<List<Podcast>> _load() => AppScope.of(context).directory.top(widget.interest.genre);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ContentColumn(child: sectionHeading(widget.interest.name.toUpperCase(), trailing: widget.trailing)),
      FutureBuilder<List<Podcast>>(
        future: _shows,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const _RowLoading(height: showRowHeight);
          if (snap.hasError) {
            return ContentColumn(
              child: _Retry(
                message: '${snap.error}.',
                retryKey: ValueKey('retry-${widget.interest.genre}'),
                onRetry: () => setState(() => _shows = _load()),
              ),
            );
          }
          final shows = snap.data!;
          if (shows.isEmpty) return ContentColumn(child: sectionHint('No top shows here right now.'));
          return ShowRow(key: ValueKey('top-${widget.interest.genre}'), shows: shows, onOpen: widget.onOpen);
        },
      ),
      const SizedBox(height: 30),
    ],
  );
}

class _RowLoading extends StatelessWidget {
  const _RowLoading({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: const Center(child: GlassProgressIndicator.circular(size: 24, color: accent)),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.retryKey, required this.onRetry});

  final String message;
  final Key retryKey;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Flexible(child: sectionHint(message)),
      const SizedBox(width: 12),
      textLink('Try again', retryKey, onRetry),
    ],
  );
}
