import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'photo_crypto.dart';

/// One background isolate that encrypts and decrypts photos for the whole
/// app, so a screen full of thumbnails doesn't start an isolate per photo.
/// Started on first use; requests run one after another, in order.
class PhotoWorker {
  PhotoWorker._();

  static final instance = PhotoWorker._();

  Future<SendPort>? _port;
  RawReceivePort? _replies;
  final _pending = <int, Completer<Uint8List>>{};
  var _next = 0;

  /// The photo inside [sealed]; throws [PhotoUnreadableException].
  Future<Uint8List> open(PhotoCipher cipher, Uint8List sealed) =>
      _run(false, cipher, sealed);

  Future<Uint8List> seal(PhotoCipher cipher, Uint8List plain) =>
      _run(true, cipher, plain);

  Future<Uint8List> _run(bool seal, PhotoCipher cipher, Uint8List bytes) async {
    final port = await (_port ??= _start());
    final id = _next++;
    final done = Completer<Uint8List>();
    _pending[id] = done;
    port.send((
      id,
      seal,
      Uint8List.fromList(cipher.keyBytes),
      TransferableTypedData.fromList([bytes]),
    ));
    return done.future;
  }

  Future<SendPort> _start() async {
    final ready = Completer<SendPort>();
    final replies = RawReceivePort()
      // Never what keeps the app (or a test) running.
      ..keepIsolateAlive = false;
    _replies = replies;
    replies.handler = (Object? message) {
      switch (message) {
        case SendPort port:
          ready.complete(port);
        case (int id, TransferableTypedData data):
          _pending.remove(id)?.complete(data.materialize().asUint8List());
        case (int id, Object error):
          _pending.remove(id)?.completeError(error);
        case null:
          // The worker died: fail what's waiting, start afresh next time.
          _reset(StateError('Photo worker stopped'));
      }
    };
    try {
      await Isolate.spawn(
        _serve,
        replies.sendPort,
        onExit: replies.sendPort,
        debugName: 'photos',
      );
    } catch (e) {
      _reset(e);
      rethrow;
    }
    return ready.future;
  }

  void _reset(Object error) {
    _replies?.close();
    _replies = null;
    _port = null;
    final waiting = [..._pending.values];
    _pending.clear();
    for (final c in waiting) {
      c.completeError(error);
    }
  }
}

void _serve(SendPort replies) {
  final requests = ReceivePort();
  replies.send(requests.sendPort);
  requests.listen((message) {
    final (id, seal, key, data) =
        message as (int, bool, Uint8List, TransferableTypedData);
    try {
      final cipher = PhotoCipher(key);
      final bytes = data.materialize().asUint8List();
      final out = seal ? cipher.seal(bytes) : cipher.open(bytes);
      replies.send((id, TransferableTypedData.fromList([out])));
    } catch (e) {
      replies.send((id, e is PhotoUnreadableException ? e : StateError('$e')));
    }
  });
}
