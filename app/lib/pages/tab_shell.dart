import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../playback/playback.dart';
import '../ui/chrome.dart';
import '../ui/style.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'search_page.dart';

/// Home, Library and Search under a floating glass tab bar, with what's
/// playing riding on top of it. Each tab keeps its own stack of pages, so the
/// bar stays put while the user browses.
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
      child: GlassScaffold(
        body: NavigatorPopHandler(
          onPopWithResult: (_) => _navigators[_index].currentState?.maybePop(),
          child: IndexedStack(
            index: _index,
            children: [
              for (final (i, tab) in _tabs.indexed)
                Navigator(
                  key: _navigators[i],
                  onGenerateRoute: (settings) => CupertinoPageRoute<void>(settings: settings, builder: (_) => tab.root),
                ),
            ],
          ),
        ),
        bottomBar: ListenableBuilder(
          listenable: playback,
          builder: (context, _) => GlassTabBar.bottom(
            key: const Key('tab-bar'),
            tabs: [
              for (final tab in _tabs) GlassTab(icon: Icon(tab.icon), activeIcon: Icon(tab.active), label: tab.label),
            ],
            selectedIndex: _index,
            onTabSelected: _select,
            horizontalPadding: math.max(20, (MediaQuery.sizeOf(context).width - _barWidth) / 2),
            bottomAccessory: const Center(child: NowPlayingBar()),
            bottomAccessoryEnabled: playback.current != null,
            bottomAccessoryHeight: 60,
            selectedIconColor: accent,
            unselectedIconColor: inkAt(0.65),
            selectedLabelColor: accent,
            unselectedLabelColor: inkAt(0.65),
            textStyle: textStyle(size: 11, weight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
