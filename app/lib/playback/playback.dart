import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';

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

/// App-wide playback: one deck, shared by every page, so audio keeps running
/// while the user browses.
class Playback extends ChangeNotifier {
  Playback({Transport? transport}) : transport = transport ?? Transport(0);

  final Transport transport;
  NowPlaying? current;
  String? error;

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
    _swapRelease(null);
    current = NowPlaying(
      label: Episode(show: podcast.title, tag: _tag(episode), title: episode.title),
      artwork: episode.artwork ?? podcast.artwork,
      podcast: podcast,
      episode: episode,
    );
    error = null;
    // Show the feed's running time while the stream buffers.
    transport.cue(episode.duration ?? 0);
    notifyListeners();
    await _thread(
      load,
      file != null ? AudioSource.file(file) : AudioSource.uri(episode.audio),
      file != null ? 'Could not play the downloaded file' : 'Could not stream this episode',
    );
  }

  /// Thread a local audio file and start playing. [release] is called once
  /// the file is no longer needed.
  Future<void> playFile(AudioSource source, String name, {VoidCallback? release}) async {
    final load = ++_loads;
    _swapRelease(release);
    error = null;
    notifyListeners();
    if (await _thread(load, source, null)) {
      current = NowPlaying(
        label: Episode(show: 'Local File', tag: 'EP. 001', title: name.replaceFirst(RegExp(r'\.[^.]+$'), '')),
      );
      notifyListeners();
    }
  }

  void _swapRelease(VoidCallback? next) {
    final previous = _release;
    _release = next;
    previous?.call();
  }

  Future<bool> _thread(int load, AudioSource source, String? failure) async {
    try {
      await transport.load(source, autoplay: true);
      return load == _loads;
    } on LoadError catch (e) {
      if (load == _loads) {
        error = failure ?? e.message;
        notifyListeners();
      }
      return false;
    }
  }

  @override
  void dispose() {
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
