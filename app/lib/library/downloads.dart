import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../podcast/models.dart';
import 'library.dart';

/// Settings key for a download folder the user picked.
const String downloadFolderSetting = 'download_folder';

/// Where downloads go unless the user picks somewhere else: `~/.tinycast/downloads`
/// on desktop; on Android and iOS the app's own documents folder, which needs no
/// permissions and is never shown to the user.
Future<String> defaultDownloadFolder() async {
  if (Platform.isAndroid || Platform.isIOS) {
    return p.join((await getApplicationDocumentsDirectory()).path, 'downloads');
  }
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home != null) return p.join(home, '.tinycast', 'downloads');
  return p.join((await getApplicationSupportDirectory()).path, 'downloads');
}

/// Whether the user may choose where downloads go (desktop only).
bool get canChooseDownloadFolder => Platform.isMacOS || Platform.isLinux || Platform.isWindows;

/// "~/.tinycast/downloads" rather than the full home path.
String prettyPath(String path) {
  final home = Platform.environment['HOME'];
  return home != null && p.isWithin(home, path) ? p.join('~', p.relative(path, from: home)) : path;
}

class _Task {
  _Task(this.podcast, this.episode);

  final Podcast podcast;
  final PodcastEpisode episode;

  /// 0–1, or null while the size is unknown.
  double? progress;
  StreamSubscription<List<int>>? subscription;
  final Completer<void> done = Completer<void>();
  bool cancelled = false;
}

/// Downloads episodes to disk and records them in the [Library].
class Downloads extends ChangeNotifier {
  Downloads(this.library, {Future<String> Function()? defaultFolder, HttpClient Function()? client})
    : _defaultFolder = defaultFolder ?? defaultDownloadFolder,
      _client = client ?? HttpClient.new;

  final Library library;
  final Future<String> Function() _defaultFolder;
  final HttpClient Function() _client;

  final Map<String, _Task> _active = {};
  final Map<String, String> _errors = {};

  static String _key(Podcast podcast, PodcastEpisode episode) => '${podcast.feed}\n${episode.id}';

  /// The folder new downloads go to.
  Future<String> folder() async => library.setting(downloadFolderSetting) ?? await _defaultFolder();

  Future<void> setFolder(String? path) => library.setSetting(downloadFolderSetting, path);

  bool isDownloading(Podcast podcast, PodcastEpisode episode) => _active.containsKey(_key(podcast, episode));

  /// Progress of a running download: 0–1, or null when the size is unknown.
  double? progress(Podcast podcast, PodcastEpisode episode) => _active[_key(podcast, episode)]?.progress;

  /// Why the last download of [episode] failed, if it did.
  String? error(Podcast podcast, PodcastEpisode episode) => _errors[_key(podcast, episode)];

  /// The downloaded file, if it is still on disk. A file removed behind the
  /// app's back is forgotten.
  String? localFile(Podcast podcast, PodcastEpisode episode) {
    final path = library.downloadPath(podcast, episode);
    if (path == null) return null;
    if (File(path).existsSync()) return path;
    unawaited(library.forgetDownload(podcast, episode));
    return null;
  }

  /// Downloads [episode] into `<folder>/<show>/<title>.<ext>`.
  Future<void> start(Podcast podcast, PodcastEpisode episode) async {
    final key = _key(podcast, episode);
    if (_active.containsKey(key) || localFile(podcast, episode) != null) return;
    final task = _active[key] = _Task(podcast, episode);
    _errors.remove(key);
    notifyListeners();

    File? part;
    final client = _client();
    try {
      final dir = Directory(p.join(await folder(), _safeName(podcast.title)));
      await dir.create(recursive: true);
      final target = _unusedPath(p.join(dir.path, _safeName(episode.title)), _extension(episode));
      part = File('$target.part');

      // Podcast hosts chain several tracking redirects before the file.
      final request = await client.getUrl(episode.audio)
        ..maxRedirects = 10;
      final response = await request.close();
      if (task.cancelled) throw const _Cancelled();
      if (response.statusCode != HttpStatus.ok) throw HttpException('HTTP ${response.statusCode}');
      final total = response.contentLength > 0 ? response.contentLength : (episode.bytes ?? -1);
      final sink = part.openWrite();
      var received = 0;
      var reported = -1.0;
      final done = task.done;
      task.subscription = response.listen(
        (chunk) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            task.progress = (received / total).clamp(0.0, 1.0);
            // Notify in 0.5% steps rather than for every chunk.
            if (task.progress! - reported >= 0.005) {
              reported = task.progress!;
              notifyListeners();
            }
          }
        },
        onError: (Object e) => done.isCompleted ? null : done.completeError(e),
        onDone: () => done.isCompleted ? null : done.complete(),
        cancelOnError: true,
      );
      try {
        await done.future;
      } finally {
        await sink.close();
      }
      if (task.cancelled) throw const _Cancelled();
      await part.rename(target);
      await library.recordDownload(podcast, episode, target);
    } on _Cancelled {
      await _discard(part);
    } on Object catch (e) {
      await _discard(part);
      if (!task.cancelled) _errors[key] = e is FileSystemException ? 'Could not save the file' : 'Download failed';
    } finally {
      client.close(force: true);
      // A cancelled task may already have been replaced by a new download.
      if (_active[key] == task) _active.remove(key);
      notifyListeners();
    }
  }

  void cancel(Podcast podcast, PodcastEpisode episode) {
    final task = _active[_key(podcast, episode)];
    if (task == null) return;
    task.cancelled = true;
    unawaited(task.subscription?.cancel());
    // A cancelled subscription never reports done, so finish it by hand;
    // start() then removes the partial file.
    if (!task.done.isCompleted) task.done.complete();
    _active.remove(_key(podcast, episode));
    notifyListeners();
  }

  /// Deletes the downloaded file and forgets it.
  Future<void> delete(Podcast podcast, PodcastEpisode episode) async {
    final path = library.downloadPath(podcast, episode);
    if (path != null) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
    await library.forgetDownload(podcast, episode);
  }

  /// Shows the downloaded file in Finder.
  Future<void> reveal(Podcast podcast, PodcastEpisode episode) async {
    final path = localFile(podcast, episode);
    if (path != null && Platform.isMacOS) await Process.run('open', ['-R', path]);
  }

  static Future<void> _discard(File? part) async {
    try {
      if (part != null && await part.exists()) await part.delete();
    } on FileSystemException {
      // Nothing to clean up.
    }
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// A file-name-safe version of [name].
String _safeName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^\.+'), '');
  final short = cleaned.length > 120 ? cleaned.substring(0, 120).trim() : cleaned;
  return short.isEmpty ? 'Untitled' : short;
}

const Map<String, String> _mimeExtensions = {
  'audio/mpeg': '.mp3',
  'audio/mp3': '.mp3',
  'audio/mp4': '.m4a',
  'audio/x-m4a': '.m4a',
  'audio/m4a': '.m4a',
  'audio/aac': '.aac',
  'audio/ogg': '.ogg',
  'audio/opus': '.opus',
  'audio/wav': '.wav',
  'audio/x-wav': '.wav',
  'audio/flac': '.flac',
  'video/mp4': '.mp4',
};

String _extension(PodcastEpisode episode) {
  final fromUrl = p.extension(episode.audio.path).toLowerCase();
  if (_mimeExtensions.containsValue(fromUrl)) return fromUrl;
  return _mimeExtensions[episode.mimeType?.toLowerCase()] ?? '.mp3';
}

/// [base] + [ext], numbered if a file of that name already exists.
String _unusedPath(String base, String ext) {
  var candidate = '$base$ext';
  for (var n = 2; File(candidate).existsSync() || File('$candidate.part').existsSync(); n++) {
    candidate = '$base ($n)$ext';
  }
  return candidate;
}
