import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tinycast/library/library.dart';

/// A fresh library in its own temporary database.
Future<Library> openTestLibrary() async {
  final dir = await Directory.systemTemp.createTemp('tinycast_test');
  return Library.open(factory: databaseFactoryFfiNoIsolate, path: p.join(dir.path, 'library.db'));
}
