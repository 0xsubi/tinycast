import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../playback/playback.dart';
import '../podcast/directory.dart';
import '../podcast/models.dart';
import '../ui/chrome.dart';
import '../ui/sections.dart';
import '../ui/style.dart';
import 'podcast_page.dart';

/// Search the podcast directory.
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
            child: PageHeading(
              title: 'Find a show',
              below: GlassSearchBar(
                key: const Key('search'),
                controller: _query,
                placeholder: 'Search podcasts',
                onChanged: _changed,
                onSubmitted: _search,
                height: 48,
                textStyle: textStyle(size: 16),
              ),
            ),
          ),
          _body(),
          SliverToBoxAdapter(child: SizedBox(height: bottomClearance(context))),
        ],
      ),
    );
  }

  Widget _body() {
    final results = _results;
    if (results == null) {
      return SliverToBoxAdapter(
        child: ContentColumn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionHeading('FEATURED'),
              _FeaturedCard(podcast: waveform, onTap: () => _open(waveform)),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<List<Podcast>>(
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
        return ShowGrid(shows: shows, onOpen: _open);
      },
    );
  }
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
        quality: cardGlass,
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
