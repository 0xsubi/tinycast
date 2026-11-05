import 'package:flutter/cupertino.dart';

import '../playback/playback.dart';
import '../ui/chrome.dart';
import '../ui/metal_ui.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'search_page.dart';

/// Home, Library and Search above a band of hardware: what's playing in a
/// display window, over a key for each tab, the open one latched down. Each
/// tab keeps its own stack of pages, so the band stays put while the user
/// browses.
class TabShell extends StatefulWidget {
  const TabShell({super.key});

  @override
  State<TabShell> createState() => _TabShellState();
}

/// Widest the tab bar grows; on a bigger window it sits centred.
const double _barWidth = 380;

const List<({String label, IconData icon, IconData active, Widget root})> _tabs = [
  (label: 'Home', icon: CupertinoIcons.house, active: CupertinoIcons.house_fill, root: HomePage()),
  (label: 'Library', icon: CupertinoIcons.square_stack, active: CupertinoIcons.square_stack_fill, root: LibraryPage()),
  (label: 'Search', icon: CupertinoIcons.search, active: CupertinoIcons.search, root: SearchPage()),
];

class _TabShellState extends State<TabShell> {
  final List<GlobalKey<NavigatorState>> _navigators = [for (final _ in _tabs) GlobalKey<NavigatorState>()];
  int _index = 0;

  /// Choosing the open tab again goes back to its first page.
  void _select(int i) {
    if (i == _index) {
      _navigators[i].currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _index = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = AppScope.of(context).playback;
    return InTabShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: NavigatorPopHandler(
                onPopWithResult: (_) => _navigators[_index].currentState?.maybePop(),
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (final (i, tab) in _tabs.indexed)
                      Navigator(
                        key: _navigators[i],
                        onGenerateRoute: (settings) =>
                            CupertinoPageRoute<void>(settings: settings, builder: (_) => tab.root),
                      ),
                  ],
                ),
              ),
            ),
          ),
          MetalBand(
            seamTop: true,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListenableBuilder(
                      listenable: playback,
                      builder: (context, _) => playback.current == null
                          ? const SizedBox.shrink()
                          : const Padding(
                              padding: EdgeInsets.only(bottom: 12),
                              child: Center(child: NowPlayingBar()),
                            ),
                    ),
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: _barWidth),
                        child: Row(
                          key: const Key('tab-bar'),
                          children: [
                            for (final (i, tab) in _tabs.indexed) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Expanded(
                                child: MetalButton(
                                  key: ValueKey('tab-${tab.label}'),
                                  onPressed: () => _select(i),
                                  height: 58,
                                  radius: 12,
                                  padding: EdgeInsets.zero,
                                  latched: i == _index,
                                  lit: i == _index,
                                  semanticLabel: tab.label,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(i == _index ? tab.active : tab.icon, size: 20),
                                      const SizedBox(height: 3),
                                      Text(
                                        tab.label,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
