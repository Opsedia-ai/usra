/// Hybrid logical clocks for sync merges (docs/sync-design.md section 12).
///
/// A clock is 64 bits: 48 bits of Unix milliseconds and a 16-bit counter. It
/// travels only inside the signed, encrypted record body, as 16 lowercase hex
/// digits (a 64-bit number would lose precision in JavaScript).
library;

// The top bit stays clear (ms below 2^47, year 6429), so clocks compare the
// same as unsigned 64-bit numbers in every language.
final _hex16 = RegExp(r'^[0-7][0-9a-f]{15}$');

/// One clock value. Compares by its 64-bit value.
final class Hlc implements Comparable<Hlc> {
  const Hlc(this.value);

  /// The clock for [ms] milliseconds with counter [counter].
  factory Hlc.at(int ms, [int counter = 0]) {
    if (ms < 0 || ms >= (1 << 48) || counter < 0 || counter > 0xffff) {
      throw ArgumentError('clock out of range');
    }
    return Hlc((ms << 16) | counter);
  }

  /// Parses the 16-hex-digit form; anything else throws [FormatException].
  factory Hlc.parse(String hex) {
    if (!_hex16.hasMatch(hex)) throw FormatException('bad clock', hex);
    // Two halves, so the top bit can't overflow int.parse.
    final high = int.parse(hex.substring(0, 8), radix: 16);
    final low = int.parse(hex.substring(8), radix: 16);
    return Hlc((high << 32) | low);
  }

  static const zero = Hlc(0);

  final int value;

  int get millis => value >>> 16;

  @override
  int compareTo(Hlc other) => value.compareTo(other.value);

  bool operator >(Hlc other) => value > other.value;
  bool operator <(Hlc other) => value < other.value;

  /// 16 lowercase hex digits.
  String toHex() {
    final high = (value >>> 32).toRadixString(16).padLeft(8, '0');
    final low = (value & 0xffffffff).toRadixString(16).padLeft(8, '0');
    return '$high$low';
  }

  @override
  bool operator ==(Object other) => other is Hlc && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => toHex();
}

/// This phone's clock. [last] is stored with the sync state so it survives
/// restarts.
class HlcClock {
  HlcClock({this.initial = Hlc.zero, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// The stored clock this phone starts from.
  final Hlc initial;
  late Hlc _last = initial;
  final DateTime Function() _now;

  Hlc get last => _last;

  /// A clock for a local write: later than every clock seen so far.
  Hlc tick() {
    final wall = Hlc.at(_now().millisecondsSinceEpoch);
    final next = wall > _last ? wall : Hlc(_last.value + 1);
    _last = next;
    return next;
  }

  /// Remembers a clock from a record that was applied.
  void observe(Hlc remote) {
    if (remote > _last) _last = remote;
  }
}
