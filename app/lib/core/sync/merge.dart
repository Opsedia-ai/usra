import 'dart:convert';

import 'canonical_json.dart';
import 'hlc.dart';

/// The group that marks a record deleted (a signed tombstone).
const deletedGroup = '_deleted';

/// How far ahead of this phone's clock a remote clock may be before its group
/// is held back (reader rule 7 in docs/sync-design.md section 12).
const maxClockSkew = Duration(minutes: 10);

/// One merge group: the values that only make sense together, and the clock
/// of the write that set them.
final class GroupEntry {
  const GroupEntry(this.value, this.clock);

  final Object? value;
  final Hlc clock;

  /// The `[values, "hlc"]` pair of the record body.
  List<Object?> toJson() => [value, clock.toHex()];

  static GroupEntry fromJson(Object? json) {
    if (json is! List || json.length != 2 || json[1] is! String) {
      throw const FormatException('bad group');
    }
    return GroupEntry(json[0], Hlc.parse(json[1] as String));
  }

  @override
  bool operator ==(Object other) =>
      other is GroupEntry &&
      other.clock == clock &&
      canonicalJson(other.value) == canonicalJson(value);

  @override
  int get hashCode => Object.hash(clock, canonicalJson(value));

  @override
  String toString() => 'GroupEntry(${canonicalJson(value)}, $clock)';
}

/// A record's groups by name.
typedef Groups = Map<String, GroupEntry>;

bool isDeleted(Groups groups) => groups[deletedGroup]?.value == true;

/// The larger clock wins; on equal clocks the value whose canonical JSON is
/// larger, byte by byte. So every phone picks the same winner whatever order
/// changes arrive in (commutative, associative, idempotent).
GroupEntry winner(GroupEntry a, GroupEntry b) {
  final byClock = a.clock.compareTo(b.clock);
  if (byClock != 0) return byClock > 0 ? a : b;
  return _compareBytes(_bytes(a.value), _bytes(b.value)) >= 0 ? a : b;
}

List<int> _bytes(Object? value) => utf8.encode(canonicalJson(value));

int _compareBytes(List<int> a, List<int> b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}

/// A clinical group the other phone changed while this phone had also
/// changed it: the winner is kept and both values are shown
/// ("changed by two people, please check").
final class MergeConflict {
  const MergeConflict({
    required this.group,
    required this.kept,
    required this.lost,
  });

  final String group;
  final GroupEntry kept;
  final GroupEntry lost;
}

final class MergeResult {
  const MergeResult(this.groups, this.conflicts);

  final Groups groups;
  final List<MergeConflict> conflicts;
}

/// Merges [remote] into [local] group by group.
///
/// [baseClocks] are each group's clock in the last server version this phone
/// merged or pushed. When both the local and the remote clock of a group
/// differ from it, two phones changed the group; if [isClinical] says it is
/// a clinical group and the values differ, the result lists a conflict,
/// **whichever side wins**, so the phone whose value overwrote the other's
/// shows it too.
///
/// Every group merges on its own, `_deleted` included, so the result is the
/// same whatever order versions arrive in. A deleted record is a view: the
/// phone hides its values (and uploads only [tombstone]) until someone
/// restores it with a newer `_deleted = false`, which re-sends every group
/// with a new clock. A deleted result never reports conflicts.
MergeResult mergeGroups(
  Groups local,
  Groups remote, {
  Map<String, Hlc> baseClocks = const {},
  bool Function(String group) isClinical = _never,
}) {
  final merged = <String, GroupEntry>{};
  final conflicts = <MergeConflict>[];
  for (final name in {...local.keys, ...remote.keys}) {
    final l = local[name];
    final r = remote[name];
    if (l == null) {
      merged[name] = r!;
      continue;
    }
    if (r == null) {
      merged[name] = l;
      continue;
    }
    final w = winner(l, r);
    merged[name] = w;
    final base = baseClocks[name];
    if (l.clock != base &&
        r.clock != base &&
        l.clock != r.clock &&
        isClinical(name) &&
        canonicalJson(l.value) != canonicalJson(r.value)) {
      conflicts.add(
        MergeConflict(group: name, kept: w, lost: identical(w, r) ? l : r),
      );
    }
  }
  if (isDeleted(merged)) return MergeResult(merged, const []);
  return MergeResult(merged, conflicts);
}

bool _never(String _) => false;

/// What a deleted record's body carries: only the signed `_deleted` group
/// (docs/sync-design.md section 12, Deletes and tombstones).
Groups tombstone(Groups groups) => {deletedGroup: groups[deletedGroup]!};

/// Splits [remote] into groups that may be applied now and groups held back
/// because their clock is more than [maxClockSkew] ahead of [now] (reader
/// rule 7). Held groups are looked at again on a later sync.
({Groups apply, Groups held}) splitFutureGroups(Groups remote, DateTime now) {
  final limit = Hlc.at(now.add(maxClockSkew).millisecondsSinceEpoch, 0xffff);
  final apply = <String, GroupEntry>{};
  final held = <String, GroupEntry>{};
  remote.forEach((name, entry) {
    (entry.clock > limit ? held : apply)[name] = entry;
  });
  return (apply: apply, held: held);
}
