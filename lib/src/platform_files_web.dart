import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<JSAny?> _request(web.IDBRequest request) {
  final result = Completer<JSAny?>();
  request.onsuccess = ((web.Event _) => result.complete(request.result)).toJS;
  request.onerror = ((web.Event _) => result.completeError(
    StateError(request.error?.message ?? 'Browser storage request failed'),
  )).toJS;
  return result.future;
}

Future<void> _completed(web.IDBTransaction transaction) {
  final result = Completer<void>();
  transaction.oncomplete = ((web.Event _) => result.complete()).toJS;
  transaction.onabort = ((web.Event _) => result.completeError(
    StateError(transaction.error?.message ?? 'Browser storage write failed'),
  )).toJS;
  return result.future;
}

Future<web.IDBDatabase> _openDatabase() async {
  final request = web.window.indexedDB.open('thiqah-files-v1', 1);
  request.onupgradeneeded = ((web.Event _) {
    (request.result as web.IDBDatabase).createObjectStore('files');
  }).toJS;
  return (await _request(request)) as web.IDBDatabase;
}

final _database = _openDatabase();
Future<Directory> getApplicationSupportDirectory() async =>
    Directory('/thiqah');

/// The local store's file operations backed by browser IndexedDB transactions.
class File {
  File(this.path);
  final String path;
  Uri get uri => Uri.parse(path);
  Directory get parent => Directory(path.substring(0, path.lastIndexOf('/')));

  Future<JSAny?> _read() async {
    final db = await _database;
    return _request(
      db.transaction('files'.toJS).objectStore('files').get(path.toJS),
    );
  }

  Future<bool> exists() async => await _read() != null;
  Future<String> readAsString() async => (await _read() as JSString).toDart;
  Future<Uint8List> readAsBytes() async =>
      (await _read() as JSUint8Array).toDart;

  Future<File> _write(JSAny value) async {
    final db = await _database;
    final transaction = db.transaction('files'.toJS, 'readwrite');
    final completed = _completed(transaction);
    transaction.objectStore('files').put(value, path.toJS);
    await completed;
    return this;
  }

  Future<File> writeAsString(String value, {bool flush = false}) =>
      _write(value.toJS);
  Future<File> writeAsBytes(List<int> value) =>
      _write(Uint8List.fromList(value).toJS);

  Future<File> rename(String destination) async {
    final db = await _database;
    final transaction = db.transaction('files'.toJS, 'readwrite');
    final completed = _completed(transaction);
    final files = transaction.objectStore('files');
    final read = files.get(path.toJS);
    read.onsuccess = ((web.Event _) {
      final value = read.result;
      if (value == null) {
        transaction.abort();
        return;
      }
      files.put(value, destination.toJS);
      files.delete(path.toJS);
    }).toJS;
    await completed;
    return File(destination);
  }

  Future<File> copy(String destination) async {
    final value = await _read();
    if (value == null) throw StateError('Missing local file');
    return File(destination)._write(value);
  }
}

class Directory {
  Directory(this.path);
  final String path;
  Future<Directory> create({bool recursive = false}) async => this;
  // Legacy per-account disk directories have never existed in the web build.
  Future<bool> exists() async => false;
  Stream<File> list({bool followLinks = true}) => const Stream.empty();
}
