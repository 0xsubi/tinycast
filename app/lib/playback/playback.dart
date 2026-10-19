import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../deck/label_layer.dart';
import '../deck/transport.dart';
import '../library/downloads.dart';
import '../library/library.dart';
import '../podcast/directory.dart';
import '../podcast/models.dart';

/// What is threaded on the deck.
class NowPlaying {
  const NowPlaying({required this.label, this.artwork, this.podcast, this.episode});

  /// The paper label's lines.
  final Episode label;
  final String? artwork;
  final Podcast? podcast;
  final PodcastEpisode? episode;
}

/// Played back again this far before where the user left off, in seconds.
const double _rewind = 10;

/// Stopped within this many seconds of the end counts as finished.
const double _finished = 15;

const Duration _saveEvery = Duration(seconds: 5);

/// App-wide playback: one deck, shared by every page, so audio keeps running
/// while the user browses. With a [library], remembers where each episode was
/// left and picks up a little before it.
class Playback extends ChangeNotifier {
  Playback({Transport? transport, this.library}) : transport = transport ?? Transport(0) {
    if (library == null) return;
    this.transport.addListener(_onTransport);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state != AppLifecycleState.resumed) _saveProgress();
      },
    );
  }

  final Transport transport;
  final Library? library;
  NowPlaying? current;
  String? error;

  AppLifecycleListener? _lifecycle;
  Timer? _saver;

  /// The transport is playing [current], so its position is [current]'s.
  bool _threaded = false;

  /// Bumped by every load, so a slow load never replaces a newer one.
  int _loads = 0;

  /// Gives up whatever access the current source needed (a sandboxed file).
  VoidCallback? _release;

  /// Thread [episode] and start playing — from [file] when it has been
  /// downloaded, streamed otherwise. If it is already on the deck, just resume.
  Future<void> playEpisode(Podcast podcast, PodcastEpisode episode, {String? file}) async {
    if (current?.episode?.id == episode.id && current?.podcast == podcast && error == null) {
      transport.play();
      return;
    }
    final load = ++_loads;
    _saveProgress();
    _threaded = false;
    _swapRelease(null);
    current = NowPlaying(
      label: Episode(show: podcast.title, tag: _tag(episode), title: episode.title),
      artwork: episode.artwork ?? podcast.artwork,
      podcast: podcast,
      episode: episode,
    );
    error = null;
    final resume = math.max(0.0, (library?.progress(podcast, episode) ?? 0) - _rewind);
    // Show the feed's running time while the stream buffers.
    transport.cue(episode.duration ?? 0, at: resume);
    notifyListeners();
    final artwork = episode.artwork ?? podcast.artwork;
    _threaded = await _thread(
      load,
      AudioSource.uri(
        file != null ? Uri.file(file) : episode.audio,
        tag: MediaItem(
          id: episode.id,
          title: episode.title,
          album: podcast.title,
          artUri: artwork == null ? null : Uri.tryParse(artwork),
        ),
      ),
      file != null ? 'Could not play the downloaded file' : 'Could not stream this episode',
      startAt: resume,
    );
  }

  /// Thread the local audio file at [uri] and start playing. [release] is
  /// called once the file is no longer needed.
  Future<void> playFile(Uri uri, String name, {VoidCallback? release}) async {
    final load = ++_loads;
    _saveProgress();
    _threaded = false;
    _swapRelease(release);
    error = null;
    notifyListeners();
    final title = name.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final source = AudioSource.uri(
      uri,
      tag: MediaItem(id: uri.toString(), title: title, album: 'Local File'),
    );
    if (await _thread(load, source, null)) {
      current = NowPlaying(
        label: Episode(show: 'Local File', tag: 'EP. 001', title: title),
      );
      notifyListeners();
    }
  }

  void _swapRelease(VoidCallback? next) {
    final previous = _release;
    _release = next;
    previous?.call();
  }

  Future<bool> _thread(int load, AudioSource source, String? failure, {double startAt = 0}) async {
    try {
      await transport.load(source, autoplay: true, startAt: startAt);
      return load == _loads;
    } on LoadError catch (e) {
      if (load == _loads) {
        error = failure ?? e.message;
        notifyListeners();
      }
      return false;
    }
  }

  /* ------------------------------------------------------------- progress -- */

  /// Saves on every pause, and every few seconds while the tape runs.
  void _onTransport() {
    if (transport.playing) {
      _saver ??= Timer.periodic(_saveEvery, (_) => _saveProgress());
    } else {
      _saver?.cancel();
      _saver = null;
      _saveProgress();
    }
  }

  /// Records how far into the threaded episode the tape is, forgetting it
  /// near the start (it would resume from the top anyway) and near the end.
  void _saveProgress() {
    final library = this.library;
    final podcast = current?.podcast;
    final episode = current?.episode;
    if (library == null || podcast == null || episode == null || !_threaded) return;
    final t = transport.time;
    final d = transport.duration;
    final keep = t > _rewind && (d <= 0 || t < d - _finished);
    unawaited(library.setProgress(podcast, episode, keep ? t : null, length: d > 0 ? d : null));
  }

  @override
  void dispose() {
    _saveProgress();
    _saver?.cancel();
    _lifecycle?.dispose();
    transport.removeListener(_onTransport);
    _swapRelease(null);
    transport.dispose();
    super.dispose();
  }
}

const List<String> _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

/// The label's corner tag: the episode number, else its release date.
String _tag(PodcastEpisode e) {
  if (e.number != null) return 'EP. ${e.number}';
  final d = e.published;
  if (d != null) return '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
  return switch (e.type) {
    'trailer' => 'TRAILER',
    'bonus' => 'BONUS',
    _ => 'EP. ···',
  };
}

/// Hands the app's services to every page.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.playback,
    required this.directory,
    required this.library,
    required this.downloads,
    required super.child,
  });

  final Playback playback;
  final PodcastDirectory directory;
  final Library library;
  final Downloads downloads;

  static AppScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.playback != playback || oldWidget.directory != directory;
}
