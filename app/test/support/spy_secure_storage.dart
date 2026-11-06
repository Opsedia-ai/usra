import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A secure storage that records every call. [failReads] makes `read` and
/// `readAll` throw, like a Keystore error with `resetOnError: false`.
class SpySecureStorage implements FlutterSecureStorage {
  SpySecureStorage({Map<String, String>? values, this.failReads = false})
    : values = values ?? {};

  final Map<String, String> values;
  final bool failReads;
  final calls = <String>[];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName
        .toString()
        .replaceFirst('Symbol("', '')
        .replaceFirst('")', '');
    calls.add(name);
    final key = invocation.namedArguments[#key] as String?;
    final error = StateError('Keystore error');
    switch (name) {
      case 'read':
        return failReads
            ? Future<String?>.error(error)
            : Future<String?>.value(values[key]);
      case 'readAll':
        return failReads
            ? Future<Map<String, String>>.error(error)
            : Future<Map<String, String>>.value(Map.of(values));
      case 'containsKey':
        return Future<bool>.value(values.containsKey(key));
      case 'write':
        values[key!] = invocation.namedArguments[#value] as String;
        return Future<void>.value();
      case 'delete':
        values.remove(key);
        return Future<void>.value();
      case 'deleteAll':
        values.clear();
        return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
