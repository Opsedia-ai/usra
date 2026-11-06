import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../log.dart';

/// How often an automatic backup is due.
enum BackupFrequency {
  daily(1),
  weekly(7),
  monthly(30);

  const BackupFrequency(this.days);

  final int days;
}

/// Why the last automatic backup didn't land. Saved with the settings, so
/// the notice survives the app closing. Holds no file names or paths.
enum AutoBackupFailure {
  /// The folder was moved or removed, the SD card is out, or access was
  /// taken away.
  folderMissing,

  /// The folder is (now) in iCloud Drive, where health data can't go.
  iCloudFolder,

  /// No space on the phone (for the file being made) or in the folder.
  noSpace,

  /// iOS: the phone locked part way, so photos can't be read (S9).
  phoneLocked,

  /// There's no recovery key on this phone to encrypt with.
  noRecoveryKey,

  /// The app was closed part way. Written before a backup starts and
  /// cleared when it ends, so a killed app can't report anything else.
  interrupted,

  /// The database came back empty after it couldn't be opened: paused, so
  /// new, near-empty backups don't push out the ones that hold the records.
  pausedForRecovery,

  /// Anything else.
  failed,
}

/// The folder backups go to, as the system hands it back.
class BackupFolder {
  const BackupFolder({
    required this.id,
    required this.name,
    required this.onThisPhone,
  });

  /// Android: the tree URI. iOS: the security-scoped bookmark, as base64.
  final String id;

  /// The folder's own name, for the Backup screen only.
  final String name;

  /// Whether losing the phone loses this folder too; null when the system
  /// doesn't say (iOS can't tell On My iPhone from another Files provider).
  final bool? onThisPhone;

  BackupFolder withId(String id) =>
      BackupFolder(id: id, name: name, onThisPhone: onThisPhone);

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'onThisPhone': onThisPhone,
  };

  static BackupFolder fromJson(Map<String, dynamic> json) => BackupFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    onThisPhone: json['onThisPhone'] as bool?,
  );
}

/// The automatic backup settings and how the last one went.
class AutoBackupSettings {
  const AutoBackupSettings({
    this.enabled = false,
    this.frequency = BackupFrequency.weekly,
    this.folder,
    this.tag = '',
    this.enabledAt,
    this.lastAt,
    this.lastSize,
    this.lastSkippedPhotos = 0,
    this.lastAttemptAt,
    this.failure,
  });

  final bool enabled;
  final BackupFrequency frequency;
  final BackupFolder? folder;

  /// Random, in this phone's file names: retention only ever deletes files
  /// with this tag, so two phones sharing a folder leave each other's alone.
  final String tag;
  final DateTime? enabledAt;

  /// The last backup that landed in the folder, and its size in bytes.
  final DateTime? lastAt;
  final int? lastSize;
  final int lastSkippedPhotos;
  final DateTime? lastAttemptAt;
  final AutoBackupFailure? failure;

  static const _unset = Object();

  AutoBackupSettings copyWith({
    bool? enabled,
    BackupFrequency? frequency,
    Object? folder = _unset,
    String? tag,
    DateTime? enabledAt,
    DateTime? lastAt,
    int? lastSize,
    int? lastSkippedPhotos,
    DateTime? lastAttemptAt,
    Object? failure = _unset,
  }) => AutoBackupSettings(
    enabled: enabled ?? this.enabled,
    frequency: frequency ?? this.frequency,
    folder: identical(folder, _unset) ? this.folder : folder as BackupFolder?,
    tag: tag ?? this.tag,
    enabledAt: enabledAt ?? this.enabledAt,
    lastAt: lastAt ?? this.lastAt,
    lastSize: lastSize ?? this.lastSize,
    lastSkippedPhotos: lastSkippedPhotos ?? this.lastSkippedPhotos,
    lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
    failure: identical(failure, _unset)
        ? this.failure
        : failure as AutoBackupFailure?,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'frequency': frequency.name,
    'folder': folder?.toJson(),
    'tag': tag,
    'enabledAt': enabledAt?.millisecondsSinceEpoch,
    'lastAt': lastAt?.millisecondsSinceEpoch,
    'lastSize': lastSize,
    'lastSkippedPhotos': lastSkippedPhotos,
    'lastAttemptAt': lastAttemptAt?.millisecondsSinceEpoch,
    'failure': failure?.name,
  };

  static DateTime? _time(Object? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms as int);

  static AutoBackupSettings fromJson(Map<String, dynamic> json) =>
      AutoBackupSettings(
        enabled: json['enabled'] as bool? ?? false,
        frequency: BackupFrequency.values.firstWhere(
          (f) => f.name == json['frequency'],
          orElse: () => BackupFrequency.weekly,
        ),
        folder: json['folder'] == null
            ? null
            : BackupFolder.fromJson(json['folder'] as Map<String, dynamic>),
        tag: json['tag'] as String? ?? '',
        enabledAt: _time(json['enabledAt']),
        lastAt: _time(json['lastAt']),
        lastSize: json['lastSize'] as int?,
        lastSkippedPhotos: json['lastSkippedPhotos'] as int? ?? 0,
        lastAttemptAt: _time(json['lastAttemptAt']),
        failure: AutoBackupFailure.values
            .where((f) => f.name == json['failure'])
            .firstOrNull,
      );
}

/// A new random tag for [AutoBackupSettings.tag].
String newBackupTag([Random? random]) {
  final rng = random ?? Random.secure();
  return rng.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
}

/// Whether the next backup is due at [now], counted in calendar days on the
/// phone's clock: a weekly backup made at 9:00 is due from 00:00 seven days
/// later, so opening the app earlier that day doesn't skip it. A last backup
/// in the future means the clock changed, which must not stop backups.
bool isBackupDue(AutoBackupSettings settings, DateTime now) {
  final last = settings.lastAt;
  if (last == null || last.isAfter(now)) return true;
  return _calendarDays(last, now) >= settings.frequency.days;
}

int _calendarDays(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// After a try that didn't finish, opening the app doesn't try again for
/// this long: making a backup is heavy for a budget phone, and something
/// that keeps failing must not run at every open. "Try again" always runs.
const autoBackupCooldown = Duration(hours: 6);

/// Whether opening the app should start a backup at [now].
bool shouldStartAutoBackup(AutoBackupSettings settings, DateTime now) {
  if (!settings.enabled || settings.folder == null) return false;
  if (!isBackupDue(settings, now)) return false;
  // Locked is over as soon as the phone is unlocked again.
  if (settings.failure == AutoBackupFailure.phoneLocked) return true;
  final attempt = settings.lastAttemptAt;
  return attempt == null ||
      attempt.isAfter(now) ||
      now.difference(attempt) >= autoBackupCooldown;
}

/// How many backups stay in the folder.
const autoBackupKeep = 3;

/// A backup file in the folder written by this feature:
/// `usra-auto-<tag>-<yyyyMMdd-HHmmss>[-p].usra`, UTC, where `-p` means some
/// photos couldn't be included. While it's being written it ends in
/// `.partial` instead. Nothing about the family is ever in the name.
class AutoBackupFileName {
  const AutoBackupFileName._(this.name, this.tag, this.stamp, this.isComplete);

  final String name;
  final String tag;
  final String stamp;

  /// Every photo is in it.
  final bool isComplete;

  static const partialExtension = '.partial';
  static const _extension = '.usra';
  static final _pattern = RegExp(
    r'^usra-auto-([0-9a-f]{8})-(\d{8}-\d{6})(-p)?\.usra$',
  );

  static String make(String tag, DateTime at, {bool complete = true}) {
    final u = at.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
        '-${two(u.hour)}${two(u.minute)}${two(u.second)}';
    return 'usra-auto-$tag-$stamp${complete ? '' : '-p'}$_extension';
  }

  /// [name] while it's being written.
  static String partialOf(String name) =>
      '${p.basenameWithoutExtension(name)}$partialExtension';

  /// Null for any name this feature didn't write: the family's own files,
  /// manual backups and so on are never touched.
  static AutoBackupFileName? parse(String name) {
    final match = _pattern.firstMatch(name);
    if (match == null) return null;
    return AutoBackupFileName._(name, match[1]!, match[2]!, match[3] == null);
  }
}

/// Which of [names] (everything in the folder) to delete now a new backup
/// has landed: this phone's backups beyond the newest [keep]. The newest
/// complete one always stays, even if it's older, so backups that had to
/// leave photos out can't push out the last one that has them all.
List<String> backupsToDelete(
  Iterable<String> names,
  String tag, {
  int keep = autoBackupKeep,
}) {
  final own =
      names
          .map(AutoBackupFileName.parse)
          .nonNulls
          .where((f) => f.tag == tag)
          .toList()
        ..sort((a, b) => b.stamp.compareTo(a.stamp));
  final kept = own.take(keep).toList();
  if (!kept.any((f) => f.isComplete)) {
    final complete = own.where((f) => f.isComplete).firstOrNull;
    if (complete != null) kept.add(complete);
  }
  return [
    for (final f in own)
      if (!kept.contains(f)) f.name,
  ];
}

/// This phone's half-written files in [names], left by a killed app.
List<String> partialsToDelete(Iterable<String> names, String tag) => [
  for (final name in names)
    if (name.endsWith(AutoBackupFileName.partialExtension) &&
        AutoBackupFileName.parse('${p.basenameWithoutExtension(name)}.usra')
                ?.tag ==
            tag)
      name,
];

/// Keeps the settings in the app's private folder rather than in
/// shared_preferences: a folder's name and path shouldn't go into an iCloud
/// device backup, and that folder is excluded (see `docs/security.md`).
/// "Delete all my data" empties it.
class AutoBackupStore {
  AutoBackupStore._(this._file, this._current);

  /// Kept only while the app runs; what tests use.
  AutoBackupStore.memory([AutoBackupSettings? initial])
    : _file = null,
      _current = initial ?? const AutoBackupSettings();

  static const fileName = 'auto_backup.json';

  final File? _file;
  AutoBackupSettings _current;

  AutoBackupSettings get current => _current;

  static Future<AutoBackupStore> open(Directory root) async {
    final file = File(p.join(root.path, fileName));
    var current = const AutoBackupSettings();
    try {
      if (await file.exists()) {
        current = AutoBackupSettings.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      // Damaged: automatic backup is off until it's set up again, and the
      // Backup screen shows that.
      Log.error('Auto backup settings unreadable', e);
    }
    return AutoBackupStore._(file, current);
  }

  /// Written to a temporary name, then renamed, so a killed app leaves the
  /// old settings or the new ones, never half of either.
  Future<void> save(AutoBackupSettings settings) async {
    _current = settings;
    final file = _file;
    if (file == null) return;
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await temp.rename(file.path);
  }
}
