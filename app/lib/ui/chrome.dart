import 'package:flutter/cupertino.dart';

import '../deck/paint_kit.dart' show white;

import '../pages/player_page.dart';
import '../playback/playback.dart';
import 'marquee.dart';
import 'metal_ui.dart';
import 'style.dart';

/// Widest the browse pages' content grows on a big window.
const double contentWidth = 960;

/// Room left under scrolling content for what floats at the bottom: the
/// now-playing bar. In the tab shell it and the tab bar sit in a band of
/// their own below the page, so only a margin is needed.
double bottomClearance(BuildContext context) => InTabShell.of(context) ? 32 : 110;

/// Marks pages shown inside the tab shell, which floats the tab bar and the
/// now-playing bar over them itself.
class InTabShell extends InheritedWidget {
  const InTabShell({super.key, required super.child});

  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<InTabShell>() != null;

  @override
  bool updateShouldNotify(InTabShell oldWidget) => false;
}

/// Opens the tape deck over everything, tab bar included, unless it is
/// already showing.
void openPlayer(BuildContext context) {
  if (ModalRoute.of(context)?.settings.name == PlayerPage.route) return;
  Navigator.of(context, rootNavigator: true).push(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: PlayerPage.route),
      fullscreenDialog: true,
      builder: (_) => const PlayerPage(),
    ),
  );
}

/// A browse page on the device's aluminium. A page that can go back gets a
/// band across the top with a back key and its [title]; outside the tab
/// shell the now-playing bar floats at the bottom.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.body, this.title});

  final Widget body;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    Widget page = body;
    if (canPop) {
      page = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MetalBand(
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
              child: SizedBox(
                height: _barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      MetalIconButton(
                        key: const Key('back'),
                        icon: CupertinoIcons.chevron_left,
                        size: 40,
                        semanticLabel: 'Back',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: title == null
                            ? const SizedBox()
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  title!.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: textStyle(size: 13, weight: FontWeight.w600, spacing: 2, alpha: 0.7),
                                ),
                              ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MediaQuery.removePadding(context: context, removeTop: true, child: body),
          ),
        ],
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        const MetalBackground(),
        page,
        if (!InTabShell.of(context))
          const Positioned(left: 16, right: 16, bottom: 20, child: Center(child: NowPlayingBar())),
      ],
    );
  }
}

const double _barHeight = 60;

/// Top padding for a page's content: clear of the status bar, or, under the
/// band of a page that can go back, a margin below it.
double appBarClearance(BuildContext context) => MediaQuery.paddingOf(context).top + 16;

/// Centres browse content and caps its width.
class ContentColumn extends StatelessWidget {
  const ContentColumn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: contentWidth),
      // Fill the capped width so content lines up on the left.
      child: SizedBox(
        width: double.infinity,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: child),
      ),
    ),
  );
}

/// What is on the deck, in a display window like the deck's own, with a key
/// to play or pause it; tap the display to open the player.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context) {
    final playback = AppScope.of(context).playback;
    return ListenableBuilder(
      listenable: Listenable.merge([playback, playback.transport]),
      builder: (context, _) {
        final now = playback.current;
        if (now == null) return const SizedBox.shrink();
        final transport = playback.transport;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const Key('now-playing'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => openPlayer(context),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: DisplayWindow(
                      radius: 12,
                      padding: const EdgeInsets.fromLTRB(9, 9, 14, 9),
                      child: Row(
                        children: [
                          Artwork(url: now.artwork, size: 40, radius: 7, shadow: false),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MarqueeText(
                                  now.label.title,
                                  style: textStyle(size: 14, weight: FontWeight.w700, color: pixel),
                                ),
                                Text(
                                  transport.buffering ? 'Buffering…' : now.label.show,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textStyle(size: 12.5, color: pixel.withValues(alpha: 0.55)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Lamp(on: transport.playing),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              MetalIconButton(
                key: const Key('now-playing-toggle'),
                icon: transport.playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                size: 52,
                iconSize: 22,
                semanticLabel: transport.playing ? 'Pause' : 'Play',
                onPressed: transport.toggle,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A quiet, non-interactive tag for metadata ("1 hr 50 min", "Explicit").
class MetaPill extends StatelessWidget {
  const MetaPill(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
    decoration: BoxDecoration(
      color: white.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: inkAt(0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 13, color: inkAt(0.6)), const SizedBox(width: 6)],
        Text(text, style: textStyle(size: 12.5, weight: FontWeight.w500, alpha: 0.8)),
      ],
    ),
  );
}

/// Centered message for empty, loading and error states.
class StateMessage extends StatelessWidget {
  const StateMessage({super.key, required this.text, this.icon, this.loading = false, this.action});

  final String text;
  final IconData? icon;
  final bool loading;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 60),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) const MetalProgress(size: 28) else if (icon != null) Icon(icon, size: 34, color: inkAt(0.4)),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center, style: textStyle(size: 14, alpha: 0.6)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}
