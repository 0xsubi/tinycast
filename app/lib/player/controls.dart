import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../deck/geometry.dart';
import '../deck/transport.dart';
import '../ui/style.dart';

TextStyle _readout({double size = 12.5, double alpha = 0.55}) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.4,
  color: ink.withValues(alpha: alpha),
  fontFeatures: const [FontFeature.tabularFigures()],
);

/// Glass transport controls under the deck: seek bar, keys, volume and load.
class PlayerControls extends StatelessWidget {
  const PlayerControls({super.key, required this.transport, required this.onLoad});

  final Transport transport;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keys = TransportKeys(transport: transport);
        final load = GlassChip(
          key: const Key('load'),
          label: 'Load episode',
          icon: const Icon(CupertinoIcons.eject_fill),
          iconColor: ink,
          labelStyle: _readout(size: 13, alpha: 0.9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          onTap: onLoad,
        );
        final compact = constraints.maxWidth < 640;
        // The controls are clicked, never focused, so Space and the arrow keys
        // always reach the player's shortcuts instead of a button or slider.
        return ExcludeFocus(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SeekBar(transport: transport),
              const SizedBox(height: 14),
              if (compact) ...[
                keys,
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: VolumeControl(transport: transport, expand: true)),
                    const SizedBox(width: 16),
                    load,
                  ],
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: VolumeControl(transport: transport),
                      ),
                    ),
                    keys,
                    Expanded(
                      child: Align(alignment: Alignment.centerRight, child: load),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Tape position slider with elapsed and remaining time. Follows playback on
/// its own ticker so the rest of the screen does not rebuild.
class SeekBar extends StatefulWidget {
  const SeekBar({super.key, required this.transport});

  final Transport transport;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _fraction = 0;
  int _second = -1;
  double _duration = 0;

  /// Thumb position while the user drags, so it never lags the pointer.
  double? _drag;

  Transport get _transport => widget.transport;

  @override
  void initState() {
    super.initState();
    _sample();
    _ticker = createTicker((_) {
      if (_sample()) setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  /// Reads the transport; true when the thumb would move visibly or a
  /// readout changes.
  bool _sample() {
    final t = _transport;
    final fraction = clamp01(t.time / math.max(1, t.duration));
    final second = t.time.floor();
    if ((fraction - _fraction).abs() < 5e-4 && second == _second && t.duration == _duration) return false;
    _fraction = fraction;
    _second = second;
    _duration = t.duration;
    return true;
  }

  void _seek(double fraction) {
    setState(() => _drag = fraction);
    _transport.seek(fraction * _transport.duration);
  }

  @override
  Widget build(BuildContext context) {
    final t = _transport;
    final time = _drag == null ? t.time : _drag! * t.duration;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassSlider(
          key: const Key('seek'),
          value: _drag ?? _fraction,
          onChanged: _seek,
          onChangeEnd: (_) => setState(() => _drag = null),
          activeColor: accent,
          inactiveColor: ink.withValues(alpha: 0.16),
          trackHeight: 5,
          thumbRadius: 13,
          glowColor: accent.withValues(alpha: 0.35),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatTime(time), key: const Key('elapsed'), style: _readout()),
              Text('-${formatTime(t.duration - time)}', key: const Key('remaining'), style: _readout()),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rewind 15 s, play / pause, forward 30 s.
class TransportKeys extends StatelessWidget {
  const TransportKeys({super.key, required this.transport});

  final Transport transport;

  @override
  Widget build(BuildContext context) {
    Widget key(String id, IconData icon, double size, VoidCallback onTap, {bool primary = false}) => GlassButton(
      key: Key(id),
      icon: Icon(icon),
      iconSize: primary ? 30 : 24,
      iconColor: ink,
      width: size,
      height: size,
      settings: primary ? accentGlass : null,
      glowColor: primary ? accent.withValues(alpha: 0.5) : null,
      onTap: onTap,
    );

    return ListenableBuilder(
      listenable: transport,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          key('rew', CupertinoIcons.gobackward_15, 54, () => transport.skip(-15)),
          const SizedBox(width: 22),
          key(
            'play',
            transport.playing ? CupertinoIcons.pause_fill : CupertinoIcons.play_fill,
            74,
            transport.toggle,
            primary: true,
          ),
          const SizedBox(width: 22),
          key('ff', CupertinoIcons.goforward_30, 54, () => transport.skip(30)),
        ],
      ),
    );
  }
}

class VolumeControl extends StatelessWidget {
  const VolumeControl({super.key, required this.transport, this.expand = false});

  final Transport transport;

  /// Stretch the slider to fill the available width instead of a fixed 150.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final icon = ink.withValues(alpha: 0.6);
    return ListenableBuilder(
      listenable: transport,
      builder: (context, _) {
        final slider = GlassSlider(
          key: const Key('volume'),
          value: transport.volume,
          onChanged: transport.setVolume,
          activeColor: ink.withValues(alpha: 0.85),
          inactiveColor: ink.withValues(alpha: 0.16),
          thumbRadius: 11,
        );
        return Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.speaker_fill, size: 15, color: icon),
            if (expand) Expanded(child: slider) else SizedBox(width: 150, child: slider),
            Icon(CupertinoIcons.speaker_3_fill, size: 15, color: icon),
          ],
        );
      },
    );
  }
}
