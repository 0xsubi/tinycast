import 'dart:async';

import 'package:flutter/foundation.dart';

import '../deck/transport.dart';

/// The lengths the sleep timer offers.
const List<Duration> sleepLengths = [
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
];

/// Pauses the tape after a while, or lets the episode run out and then
/// forgets itself. App-wide, so it keeps counting with the deck closed.
class SleepTimer extends ChangeNotifier {
  SleepTimer(this.transport) {
    transport.addListener(_onTransport);
  }

  final Transport transport;

  /// The length chosen, while counting down.
  Duration? get length => _length;
  Duration? _length;

  /// Sleeping when the episode ends.
  bool get endOfEpisode => _endOfEpisode;
  bool _endOfEpisode = false;

  DateTime? _deadline;
  Timer? _alarm;
  Timer? _ticker;

  bool get active => _endOfEpisode || _deadline != null;

  /// Time left on the countdown; null unless counting down.
  Duration? get remaining {
    final deadline = _deadline;
    if (deadline == null) return null;
    final left = deadline.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Pause the tape [length] from now.
  void start(Duration length) {
    _clear();
    _length = length;
    _deadline = DateTime.now().add(length);
    _alarm = Timer(length, _sleep);
    // The readout counts down by the second.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    notifyListeners();
  }

  /// Sleep once the episode playing now runs out.
  void untilEndOfEpisode() {
    _clear();
    _endOfEpisode = true;
    notifyListeners();
  }

  void cancel() {
    if (!active) return;
    _clear();
    notifyListeners();
  }

  void _sleep() {
    transport.pause();
    cancel();
  }

  /// The tape stopping at its end is the end of the episode: the deck threads
  /// nothing after it, so there is nothing more to stop.
  void _onTransport() {
    if (_endOfEpisode && !transport.playing && transport.duration > 0 && transport.time >= transport.duration - 1) {
      cancel();
    }
  }

  void _clear() {
    _alarm?.cancel();
    _ticker?.cancel();
    _alarm = _ticker = null;
    _deadline = null;
    _length = null;
    _endOfEpisode = false;
  }

  @override
  void dispose() {
    _clear();
    transport.removeListener(_onTransport);
    super.dispose();
  }
}

/// "14:32" left on the timer, or "1:00:00"; "END" when sleeping at the end
/// of the episode; null when off.
String? sleepReadout(SleepTimer timer) {
  if (timer.endOfEpisode) return 'END';
  final left = timer.remaining;
  if (left == null) return null;
  // Round up, so a fresh 5-minute timer reads 5:00 and it never shows 0:00 while running.
  final s = (left.inMilliseconds / 1000).ceil();
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// "5 min", "1 hour".
String sleepLabel(Duration d) => d.inMinutes >= 60 ? '${d.inHours} hour' : '${d.inMinutes} min';
