import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Playback clock for the deck. Drives a real audio player once a file is
/// loaded; until then it runs a silent simulated clock so the deck still plays.
/// Time is read every animation frame, so it is exposed as a getter rather
/// than notified; only discrete changes (play/pause/duration) notify. Loudness is
/// left to the system volume.
class Transport extends ChangeNotifier {
  Transport(this.duration, {double startAt = 0}) : _simTime = startAt;

  bool playing = false;

  /// A stream is loading or refilling its buffer: playback is wanted but the
  /// tape is not moving yet.
  bool buffering = false;
  double duration;

  /// Which way the tape is winding after a [skip]: -1 back, 1 forward, 0 not
  /// winding. The deck calls [wound] once its reels have caught up.
  int winding = 0;

  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  double _simTime;
  double _simAnchor = 0;
  final Stopwatch _clock = Stopwatch()..start();

  double get _now => _clock.elapsedMicroseconds / 1e6;

  double get time {
    final player = _player;
    if (player != null) return player.position.inMicroseconds / 1e6;
    if (!playing) return _simTime;
    return math.min(duration, _simTime + _now - _simAnchor);
  }

  /// Called once per frame; stops the simulated clock at the end of the tape.
  void tick() {
    if (_player == null && playing && time >= duration) {
      _simTime = duration;
      playing = false;
      notifyListeners();
    }
  }

  void play() {
    if (playing) return;
    if (time >= duration - 0.25) seek(0);
    final player = _player;
    if (player != null) {
      // State follows the player's state stream. play() completes only when
      // playback stops, so it is not awaited.
      unawaited(player.play().catchError((_) {}));
      return;
    }
    _simAnchor = _now;
    playing = true;
    notifyListeners();
  }

  void pause() {
    if (!playing) return;
    final player = _player;
    if (player != null) {
      unawaited(player.pause());
      return;
    }
    _simTime = time;
    playing = false;
    notifyListeners();
  }

  void toggle() => playing ? pause() : play();

  void seek(double t) {
    final c = t.clamp(0.0, math.max(0.0, duration)).toDouble();
    final player = _player;
    if (player != null) {
      unawaited(player.seek(Duration(microseconds: (c * 1e6).round())));
    } else {
      _simTime = c;
      _simAnchor = _now;
    }
  }

  void skip(double delta) {
    seek(time + delta);
    winding = delta.sign.toInt();
    notifyListeners();
  }

  /// The deck has finished winding to the [skip]'s target.
  void wound() {
    if (winding == 0) return;
    winding = 0;
    notifyListeners();
  }

  /// Set the tape length (and position) shown while no audio is loaded, or
  /// while a stream is still buffering.
  void cue(double length, {double at = 0}) {
    duration = length;
    if (_player == null) {
      _simTime = at.clamp(0.0, length).toDouble();
      _simAnchor = _now;
    }
    notifyListeners();
  }

  /// Thread a new audio source, positioned [startAt] seconds in. Completes
  /// with its duration in seconds. With [autoplay], playback starts as soon as
  /// enough has buffered.
  Future<double> load(AudioSource source, {bool autoplay = false, double startAt = 0}) async {
    await _unload();
    final player = AudioPlayer();
    _player = player;
    playing = false;
    notifyListeners();

    _stateSub = player.playerStateStream.listen((s) {
      if (_player != player) return;
      final ended = s.processingState == ProcessingState.completed;
      // just_audio stays "playing" at the end of a track; park it instead.
      if (ended && s.playing) unawaited(player.pause());
      final now = s.playing && !ended;
      final waiting = s.processingState == ProcessingState.loading || s.processingState == ProcessingState.buffering;
      if (now != playing || waiting != buffering) {
        playing = now;
        buffering = waiting;
        notifyListeners();
      }
    });

    try {
      final loading = player.setAudioSource(
        source,
        initialPosition: startAt > 0 ? Duration(microseconds: (startAt * 1e6).round()) : null,
      );
      if (autoplay) unawaited(player.play().catchError((_) {}));
      final d = await loading;
      if (_player != player) return duration;
      duration = d == null ? 0 : d.inMicroseconds / 1e6;
      notifyListeners();
      return duration;
    } catch (_) {
      if (_player == player) await _unload();
      throw const LoadError('Could not load that audio file');
    }
  }

  Future<void> _unload() async {
    final old = _player;
    if (old == null) return;
    _player = null;
    await _stateSub?.cancel();
    _stateSub = null;
    playing = false;
    buffering = false;
    await old.dispose();
  }

  @override
  void dispose() {
    unawaited(_unload());
    super.dispose();
  }
}

class LoadError implements Exception {
  const LoadError(this.message);
  final String message;

  @override
  String toString() => message;
}
