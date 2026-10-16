import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Playback clock for the deck. Drives a real audio player once a file is
/// loaded; until then it runs a silent simulated clock so the deck still plays.
/// Time is read every animation frame, so it is exposed as a getter rather
/// than notified; only discrete changes (play/pause/volume/duration) notify.
class Transport extends ChangeNotifier {
  Transport(this.duration, {double startAt = 0}) : _simTime = startAt;

  bool playing = false;
  double duration;
  double volume = 0.72;

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

  void skip(double delta) => seek(time + delta);

  void setVolume(double v) {
    volume = v.clamp(0.0, 1.0).toDouble();
    unawaited(_player?.setVolume(volume));
    notifyListeners();
  }

  /// Thread a new audio source. Completes with its duration in seconds.
  Future<double> load(AudioSource source) async {
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
      if (now != playing) {
        playing = now;
        notifyListeners();
      }
    });

    try {
      await player.setVolume(volume);
      final d = await player.setAudioSource(source);
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
