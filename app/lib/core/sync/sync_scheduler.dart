import 'dart:async';
import 'dart:math';

/// Why a sync runs.
enum SyncReason {
  /// The app opened or came back to the foreground: pull, then push
  /// everything waiting, history bundles included.
  open,

  /// The 20-second debounce after edits ended, or the app went to the
  /// background with edits waiting: push ordinary edits; history bundles
  /// keep waiting for their jitter.
  edits,

  /// A history bundle's random 10–40 minute wait ended while the app was
  /// open: push everything.
  history,

  /// Pull-to-refresh.
  manual,
}

typedef TimerFactory = Timer Function(Duration delay, void Function() callback);

/// Decides when sync runs (docs/sync-design.md section 22, rule 1): when the
/// app opens, after edits (debounced), and on pull-to-refresh. Never on a
/// repeating timer and never while the app is in the background; the only
/// timers are the debounce and the history jitter, both cancelled when the
/// app goes to the background.
///
/// Runs never overlap: a trigger during a run queues one more run.
class SyncScheduler {
  SyncScheduler({
    required this.run,
    this.debounce = const Duration(seconds: 20),
    this.historyMin = const Duration(minutes: 10),
    this.historyMax = const Duration(minutes: 40),
    Random? random,
    TimerFactory? timer,
  }) : _random = random ?? Random.secure(),
       _timer = timer ?? Timer.new;

  /// Runs one sync; the scheduler never starts two at once.
  final Future<void> Function(SyncReason reason) run;
  final Duration debounce;
  final Duration historyMin;
  final Duration historyMax;
  final Random _random;
  final TimerFactory _timer;

  Timer? _debounceTimer;
  Timer? _historyTimer;
  bool _foreground = true;
  bool _editsWaiting = false;
  bool _historyWaiting = false;
  bool _running = false;
  SyncReason? _queued;
  bool _disposed = false;

  /// True while edits or history bundles wait to be pushed.
  bool get hasWaiting => _editsWaiting || _historyWaiting;

  void appOpened() {
    _foreground = true;
    _cancelTimers();
    _editsWaiting = false;
    _historyWaiting = false;
    _trigger(SyncReason.open);
  }

  /// Pull-to-refresh.
  void refresh() => _trigger(SyncReason.manual);

  /// A local edit. [history] is true for dose logs, temperatures and given
  /// medicines: their upload waits a random 10–40 minutes (or the next app
  /// open) so the server doesn't learn when a dose was taken (section 13).
  void edited({bool history = false}) {
    if (_disposed) return;
    if (history) {
      _historyWaiting = true;
      if (_foreground && _historyTimer == null) {
        final spread = historyMax - historyMin;
        final delay =
            historyMin +
            Duration(milliseconds: _random.nextInt(spread.inMilliseconds + 1));
        _historyTimer = _timer(delay, () {
          _historyTimer = null;
          if (!_foreground) return;
          _historyWaiting = false;
          _editsWaiting = false;
          _debounceTimer?.cancel();
          _debounceTimer = null;
          _trigger(SyncReason.history);
        });
      }
      return;
    }
    _editsWaiting = true;
    if (!_foreground) return;
    _debounceTimer?.cancel();
    _debounceTimer = _timer(debounce, () {
      _debounceTimer = null;
      _editsWaiting = false;
      _trigger(SyncReason.edits);
    });
  }

  /// The app went to the background: ordinary edits go up now; history
  /// bundles wait for the next open. No timer keeps running.
  void appPaused() {
    _foreground = false;
    _cancelTimers();
    if (_editsWaiting) {
      _editsWaiting = false;
      _trigger(SyncReason.edits);
    }
  }

  void dispose() {
    _disposed = true;
    _cancelTimers();
  }

  void _cancelTimers() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _historyTimer?.cancel();
    _historyTimer = null;
  }

  void _trigger(SyncReason reason) {
    if (_disposed) return;
    if (_running) {
      _queued = _stronger(_queued, reason);
      return;
    }
    _running = true;
    unawaited(_loop(reason));
  }

  Future<void> _loop(SyncReason first) async {
    SyncReason? next = first;
    while (next != null && !_disposed) {
      try {
        await run(next);
      } on Object {
        // The engine reports its own failures; the next trigger retries.
      }
      next = _queued;
      _queued = null;
    }
    _running = false;
  }

  // An open (or manual or history run) also pushes ordinary edits, so it
  // replaces a queued edits run.
  static SyncReason _stronger(SyncReason? a, SyncReason b) {
    if (a == null) return b;
    return a == SyncReason.edits ? b : a;
  }
}
