import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../library/searches.dart';
import '../playback/playback.dart';
import '../podcast/models.dart';
import '../ui/chrome.dart';
import '../ui/sections.dart';
import '../ui/style.dart';
import 'podcast_page.dart';

/// Search the podcast directory. Before a search, lists the recent ones.
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

  /// Searches on Return, and remembers the term; a term typed and left is not.
  void _submit(String text) {
    _search(text);
    unawaited(rememberSearch(AppScope.of(context).library, text));
  }

  /// Searches [term] again, from the recent ones.
  void _repeat(String term) {
    _query.value = TextEditingValue(
      text: term,
      selection: TextSelection.collapsed(offset: term.length),
    );
    _submit(term);
  }

  /// Opens a show from the results; the search found it, so it is remembered.
  void _open(Podcast podcast) {
    if (_term case final term?) unawaited(rememberSearch(AppScope.of(context).library, term));
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => PodcastPage(podcast: podcast)));
  }

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
                onSubmitted: _submit,
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
      final library = AppScope.of(context).library;
      return SliverToBoxAdapter(
        child: ContentColumn(
          child: ListenableBuilder(
            listenable: library,
            builder: (context, _) {
              final recent = recentSearches(library);
              if (recent.isEmpty) return sectionHint('Search millions of shows from the Apple Podcasts directory.');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  sectionHeading(
                    'RECENT SEARCHES',
                    trailing: textLink('Clear', const Key('clear-searches'), () => clearRecentSearches(library)),
                  ),
                  for (final term in recent) _RecentSearch(term: term, onTap: () => _repeat(term)),
                ],
              );
            },
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

/// A recent search term; tap to search it again.
class _RecentSearch extends StatelessWidget {
  const _RecentSearch({required this.term, required this.onTap});

  final String term;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: ValueKey('recent-$term'),
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: inkAt(0.08), width: 0.5)),
        ),
        child: Row(
          children: [
            Icon(CupertinoIcons.clock, color: inkAt(0.45), size: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Text(term, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle(size: 16)),
            ),
            Icon(CupertinoIcons.arrow_up_left, color: inkAt(0.35), size: 16),
          ],
        ),
      ),
    ),
  );
}
