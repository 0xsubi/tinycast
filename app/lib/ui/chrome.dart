import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../pages/player_page.dart';
import '../playback/playback.dart';
import 'style.dart';

/// Widest the browse pages' content grows on a big window.
const double contentWidth = 960;

/// Room left under scrolling content for the floating now-playing bar.
const double nowPlayingClearance = 110;

/// Opens the tape deck, unless it is already showing.
void openPlayer(BuildContext context) {
  if (ModalRoute.of(context)?.settings.name == PlayerPage.route) return;
  Navigator.of(context).push(
    CupertinoPageRoute<void>(
      settings: const RouteSettings(name: PlayerPage.route),
      fullscreenDialog: true,
      builder: (_) => const PlayerPage(),
    ),
  );
}

/// A browse page: glass app bar with a back button over a [Backdrop], and the
/// now-playing bar floating at the bottom.
class GlassPageFrame extends StatelessWidget {
  const GlassPageFrame({super.key, required this.body, this.artwork, this.title});

  final Widget body;
  final String? artwork;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return GlassScaffold(
      appBarHeight: _barHeight,
      background: Backdrop(artwork: artwork),
      appBar: canPop
          ? GlassAppBar(
              toolbarHeight: _barHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              leading: GlassIconButton(
                key: const Key('back'),
                icon: Icon(CupertinoIcons.chevron_left, color: ink, size: 20),
                semanticLabel: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: title == null
                  ? null
                  : Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle(size: 15, weight: FontWeight.w600),
                    ),
            )
          : null,
      bodyOverlays: const [Positioned(left: 16, right: 16, bottom: 20, child: Center(child: NowPlayingBar()))],
      body: body,
    );
  }
}

const double _barHeight = 60;

/// Top padding that clears the glass app bar.
double appBarClearance(BuildContext context) => MediaQuery.paddingOf(context).top + _barHeight + 16;

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

/// Floating pill showing what is on the deck; tap to open the player.
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
          child: GestureDetector(
            key: const Key('now-playing'),
            behavior: HitTestBehavior.opaque,
            onTap: () => openPlayer(context),
            child: GlassContainer(
              shape: const LiquidRoundedSuperellipse(borderRadius: 24),
              padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
              child: Row(
                children: [
                  Artwork(url: now.artwork, size: 44, radius: 10, shadow: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          now.label.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle(size: 14, weight: FontWeight.w600),
                        ),
                        Text(
                          transport.buffering ? 'Buffering…' : now.label.show,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textStyle(size: 12.5, alpha: 0.55),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    key: const Key('now-playing-toggle'),
                    behavior: HitTestBehavior.opaque,
                    onTap: transport.toggle,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        transport.playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
                        color: ink,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
      color: inkAt(0.07),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: inkAt(0.1)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 13, color: inkAt(0.7)), const SizedBox(width: 6)],
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
        if (loading)
          const GlassProgressIndicator.circular(size: 28, color: accent)
        else if (icon != null)
          Icon(icon, size: 34, color: inkAt(0.4)),
        const SizedBox(height: 14),
        Text(text, textAlign: TextAlign.center, style: textStyle(size: 14, alpha: 0.6)),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}
