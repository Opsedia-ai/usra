import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Follow-ups hidden for their current cycle ([FollowUp.cycleKey]s).
///
/// A tiny key-value file rather than the database: it's a display
/// preference, not health data, and needs no schema change. The keys hold
/// only record and profile ids, rule names and dates.
abstract class DismissalStore {
  Set<String> load();
  Future<void> save(Set<String> keys);
}

/// Kept only while the app runs; what tests use.
class MemoryDismissalStore implements DismissalStore {
  MemoryDismissalStore([Set<String>? keys]) : _keys = {...?keys};

  Set<String> _keys;

  @override
  Set<String> load() => {..._keys};

  @override
  Future<void> save(Set<String> keys) async => _keys = {...keys};
}

/// A JSON list in the app's private support folder.
class FileDismissalStore implements DismissalStore {
  FileDismissalStore._(this._file, this._keys);

  static const fileName = 'follow_up_dismissals.json';

  /// Reads the file once; a missing or unreadable file starts empty.
  static Future<FileDismissalStore> open([Directory? folder]) async {
    final dir = folder ?? await getApplicationSupportDirectory();
    final file = File(p.join(dir.path, fileName));
    var keys = <String>{};
    try {
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) keys = decoded.whereType<String>().toSet();
      }
    } on FormatException {
      // Corrupt: start again; at worst a hidden follow-up shows again.
    } on FileSystemException {
      // Unreadable: same.
    }
    return FileDismissalStore._(file, keys);
  }

  final File _file;
  Set<String> _keys;
  Future<void> _writing = Future.value();

  @override
  Set<String> load() => {..._keys};

  /// Writes are queued so a quick dismiss-then-undo lands in order.
  @override
  Future<void> save(Set<String> keys) {
    _keys = {...keys};
    final json = jsonEncode(_keys.toList()..sort());
    return _writing = _writing.then((_) async {
      await _file.parent.create(recursive: true);
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(json, flush: true);
      await tmp.rename(_file.path);
    });
  }
}

/// Overridden in `main.dart` with [FileDismissalStore].
final dismissalStoreProvider = Provider<DismissalStore>(
  (ref) => MemoryDismissalStore(),
);

final dismissedFollowUpsProvider =
    NotifierProvider<DismissedFollowUps, Set<String>>(DismissedFollowUps.new);

class DismissedFollowUps extends Notifier<Set<String>> {
  @override
  Set<String> build() => ref.watch(dismissalStoreProvider).load();

  Future<void> dismiss(String cycleKey) => _set({...state, cycleKey});

  Future<void> restore(String cycleKey) => _set({...state}..remove(cycleKey));

  Future<void> _set(Set<String> keys) {
    state = keys;
    return ref.read(dismissalStoreProvider).save(keys);
  }
}
