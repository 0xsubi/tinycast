import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../deck/label_layer.dart';
import '../deck/tape_deck.dart';
import '../playback/playback.dart';
import '../playback/sleep_timer.dart';
import '../player/metal_controls.dart';
import '../ui/metal_ui.dart';
import '../ui/style.dart' show textStyle;

/// Shown on the label before anything is threaded.
const Episode _blank = Episode(show: 'tinycast', tag: '', title: 'No tape threaded');

/// The tape deck.
class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  static const String route = '/player';

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  Playback get _playback => AppScope.of(context).playback;

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final transport = _playback.transport;
    final key = e.logicalKey;
    if (key == LogicalKeyboardKey.space) {
      if (e is KeyDownEvent) transport.toggle();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      transport.skip(-15);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      transport.skip(30);
    } else if (key == LogicalKeyboardKey.escape) {
      if (e is KeyDownEvent) Navigator.of(context).maybePop();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final playback = _playback;
    final transport = playback.transport;
    final canPop = Navigator.of(context).canPop();
    return CupertinoPageScaffold(
      child: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: MetalDevice(
          transport: transport,
          deck: (unit, upright) => ListenableBuilder(
            listenable: Listenable.merge([playback, playback.sleep]),
            builder: (context, _) => TapeDeck(
              transport: transport,
              episode: playback.current?.label ?? _blank,
              unit: unit,
              upright: upright,
              failed: playback.error != null,
              onSleep: () => showSleepOptions(context, playback.sleep),
              sleep: sleepReadout(playback.sleep),
              leading: canPop
                  ? ExcludeFocus(
                      child: MetalIconButton(
                        key: const Key('close-player'),
                        size: bandButtonSize(unit),
                        icon: CupertinoIcons.chevron_down,
                        semanticLabel: 'Close player',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// The sleep timer's choices, the one running latched down: a length, or the
/// end of the episode. Turn off stops it.
Future<void> showSleepOptions(BuildContext context, SleepTimer timer) {
  void close() => Navigator.of(context, rootNavigator: true).pop();
  void choose(VoidCallback set) {
    set();
    close();
  }

  Widget option(String label, Key key, {required bool on, required VoidCallback onPressed}) => MetalButton(
    key: key,
    onPressed: onPressed,
    height: 46,
    radius: 12,
    padding: EdgeInsets.zero,
    latched: on,
    lit: on,
    child: Text(label),
  );

  return showMetalDialog<void>(
    context: context,
    title: 'Sleep timer',
    maxWidth: 360,
    content: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: ListenableBuilder(
        listenable: timer,
        builder: (context, _) {
          final keys = [
            for (final length in sleepLengths)
              option(
                sleepLabel(length),
                Key('sleep-${length.inMinutes}'),
                on: timer.length == length,
                onPressed: () => choose(() => timer.start(length)),
              ),
            option(
              'End of episode',
              const Key('sleep-end'),
              on: timer.endOfEpisode,
              onPressed: () => choose(timer.untilEndOfEpisode),
            ),
          ];
          return Column(
            children: [
              Text(
                switch (sleepReadout(timer)) {
                  null => 'Pause playback after',
                  'END' => 'Pausing at the end of this episode',
                  final left => 'Pausing in $left',
                },
                textAlign: TextAlign.center,
                style: textStyle(size: 14, alpha: 0.65),
              ),
              const SizedBox(height: 16),
              // Two to a row.
              for (var i = 0; i < keys.length; i += 2) ...[
                if (i > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: keys[i]),
                    const SizedBox(width: 10),
                    Expanded(child: keys[i + 1]),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    ),
    actions: [
      if (timer.active) MetalDialogAction(label: 'Turn off', onPressed: () => choose(timer.cancel)),
      MetalDialogAction(label: 'Close', onPressed: close),
    ],
  );
}
