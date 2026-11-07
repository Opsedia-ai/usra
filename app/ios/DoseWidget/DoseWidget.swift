// Home-screen widget: the next three doses today across the family.
//
// The `DoseWidget` app extension target in Runner.xcodeproj (see README.md).
//
// The database is encrypted, so the widget never reads it: the app saves a
// small snapshot (first names, medicine names, times; see
// `lib/features/medicines/dose_widget.dart`) in the App Group, and the
// widget picks the next three doses as time passes, rolling over at
// midnight without the app. Tapping it opens the Medicines tab. On iOS 17+ a
// dose that's due can have a Taken button, which writes to an inbox in the
// App Group for the app to save when it next runs (the same line the
// notification's Taken writes; see `DoseActionInbox`).

import AppIntents
import SwiftUI
import WidgetKit

private let appGroup = "group.com.opsedia.usra"
private let dataKey = "dose_widget_snapshot"
/// Doses marked Taken here, by "medicine@at", that aren't in a snapshot yet.
private let pendingKey = "dose_widget_taken"
/// Read by `DoseActionInbox.openWidgetInbox` in the app.
private let inboxFile = "dose_actions.jsonl"
private let openURL = URL(string: "usra://widget/medicines?homeWidget")!
private let shown = 3

/// Gallery and fallback text in the phone's language (ar.lproj / en.lproj).
/// Once the app has published a snapshot, its own title and texts win.
private func text(_ key: String) -> String { NSLocalizedString(key, comment: "") }
private let phoneIsArabic = Bundle.main.preferredLocalizations.first == "ar"

struct WidgetDose: Decodable {
  let at: Int64
  let until: Int64
  let time: String
  let person: String
  let medicine: String
  let m: String
  /// May have Taken once due: the app decides (never on a neutral row that
  /// could be someone else's dose). Missing in older snapshots.
  let t: Bool?

  var key: String { "\(m)@\(at)" }
  var date: Date { Date(timeIntervalSince1970: TimeInterval(at) / 1000) }
  /// When it leaves the widget: an hour after it's due or its snooze ends.
  var untilDate: Date { Date(timeIntervalSince1970: TimeInterval(until) / 1000) }
  /// Discreet mode sends no person and a generic medicine.
  var line: String { [time, person, medicine].filter { !$0.isEmpty }.joined(separator: " · ") }
}

struct WidgetSnapshot: Decodable {
  let v: Int
  let generatedAt: Int64
  let validUntil: Int64
  let rtl: Bool
  let title: String
  let empty: String
  let stale: String
  let taken: String?
  let doses: [WidgetDose]

  var validUntilDate: Date { Date(timeIntervalSince1970: TimeInterval(validUntil) / 1000) }

  static func load() -> WidgetSnapshot? {
    guard let raw = UserDefaults(suiteName: appGroup)?.string(forKey: dataKey),
      let data = raw.data(using: .utf8),
      let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
      snapshot.v == 1
    else { return nil }
    return snapshot
  }
}

/// Doses marked Taken here that the app hasn't saved yet. Forgets the ones a
/// later snapshot has seen and old ones.
private func pendingTaken(_ snapshot: WidgetSnapshot?) -> Set<String> {
  guard let defaults = UserDefaults(suiteName: appGroup) else { return [] }
  let raw = (defaults.string(forKey: pendingKey)?.data(using: .utf8)).flatMap {
    try? JSONDecoder().decode([String: Int64].self, from: $0)
  } ?? [:]
  let oldest = Int64((Date().timeIntervalSince1970 - 2 * 24 * 60 * 60) * 1000)
  let keep = raw.filter { $0.value >= oldest && (snapshot?.generatedAt ?? 0) <= $0.value }
  if keep.count != raw.count { savePending(keep, defaults) }
  return Set(keep.keys)
}

private func savePending(_ pending: [String: Int64], _ defaults: UserDefaults) {
  guard let data = try? JSONEncoder().encode(pending) else { return }
  defaults.set(String(decoding: data, as: UTF8.self), forKey: pendingKey)
}

/// Leaves the dose for the app, as the notification's Taken does. False if it
/// couldn't be saved: the row stays.
private func markTaken(medicineId: String, at: Int64) -> Bool {
  let now = Int64(Date().timeIntervalSince1970 * 1000)
  guard
    let defaults = UserDefaults(suiteName: appGroup),
    let folder = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroup),
    let json = try? JSONSerialization.data(
      withJSONObject: ["m": medicineId, "s": at, "st": "taken", "at": now] as [String: Any])
  else { return false }
  let url = folder.appendingPathComponent(inboxFile)
  let line = json + Data("\n".utf8)
  do {
    if FileManager.default.fileExists(atPath: url.path) {
      let handle = try FileHandle(forWritingTo: url)
      defer { try? handle.close() }
      try handle.seekToEnd()
      try handle.write(contentsOf: line)
    } else {
      try line.write(to: url, options: .atomic)
    }
  } catch {
    return false
  }
  var pending = (defaults.string(forKey: pendingKey)?.data(using: .utf8)).flatMap {
    try? JSONDecoder().decode([String: Int64].self, from: $0)
  } ?? [:]
  pending["\(medicineId)@\(at)"] = now
  savePending(pending, defaults)
  return true
}

@available(iOS 17.0, *)
struct MarkDoseTakenIntent: AppIntent {
  static var title: LocalizedStringResource = "widget.takenIntent"
  // Only for the widget's button: not offered in Shortcuts or search.
  static var isDiscoverable = false
  static var openAppWhenRun = false

  @Parameter(title: "widget.takenIntent") var medicineId: String
  @Parameter(title: "widget.takenIntent") var at: Int

  init() {}

  init(medicineId: String, at: Int64) {
    self.medicineId = medicineId
    self.at = Int(at)
  }

  func perform() async throws -> some IntentResult {
    _ = markTaken(medicineId: medicineId, at: Int64(at))
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

struct DoseRow {
  let line: String
  /// Shows Taken: the dose is due and the app allows it.
  let dose: WidgetDose?
}

struct DoseEntry: TimelineEntry {
  let date: Date
  let title: String
  let rtl: Bool
  let rows: [DoseRow]
  let taken: String
  /// Shown when there are no doses: nothing today, or open the app.
  let message: String
}

struct DoseProvider: TimelineProvider {
  func placeholder(in context: Context) -> DoseEntry {
    DoseEntry(
      date: Date(), title: text("widget.title"), rtl: phoneIsArabic,
      rows: [DoseRow(line: text("widget.sample"), dose: nil)], taken: "", message: "")
  }

  func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> Void) {
    completion(context.isPreview ? placeholder(in: context) : entry(at: Date(), WidgetSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) {
    let now = Date()
    let snapshot = WidgetSnapshot.load()
    // Redraw when a dose comes due or drops off, and at midnight.
    let calendar = Calendar.current
    let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
    var times: Set<Date> = [now, tomorrow]
    if let s = snapshot {
      times.insert(s.validUntilDate)
      for d in s.doses {
        times.insert(d.date)
        times.insert(d.untilDate.addingTimeInterval(1))
      }
    }
    let end = calendar.date(byAdding: .day, value: 1, to: tomorrow)!
    let entries = times.filter { $0 >= now && $0 <= end }.sorted().map { entry(at: $0, snapshot) }
    completion(Timeline(entries: entries, policy: .after(tomorrow)))
  }

  private func entry(at date: Date, _ snapshot: WidgetSnapshot?) -> DoseEntry {
    guard let s = snapshot, date < s.validUntilDate else {
      return DoseEntry(
        date: date, title: snapshot?.title ?? text("widget.title"),
        rtl: snapshot?.rtl ?? phoneIsArabic,
        rows: [], taken: "", message: snapshot?.stale ?? text("widget.stale"))
    }
    let calendar = Calendar.current
    let pending = pendingTaken(s)
    let due = s.doses.filter {
      $0.untilDate >= date && calendar.isDate($0.date, inSameDayAs: date)
        && !pending.contains($0.key)
    }
    return DoseEntry(
      date: date, title: s.title, rtl: s.rtl,
      rows: due.prefix(shown).map { d in
        // Only doses already due: a later one still has its reminder
        // coming, which Taken here can't cancel.
        DoseRow(line: d.line, dose: d.t == true && d.date <= date ? d : nil)
      },
      taken: s.taken ?? "", message: s.empty)
  }
}

struct DoseWidgetView: View {
  let entry: DoseEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(entry.title)
        .font(.headline)
        .foregroundColor(.accentColor)
      if entry.rows.isEmpty {
        Text(entry.message)
          .font(.title3)
      } else {
        ForEach(Array(entry.rows.prefix(family == .systemSmall ? 2 : shown).enumerated()), id: \.offset) {
          row($0.element)
        }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
    .environment(\.layoutDirection, entry.rtl ? .rightToLeft : .leftToRight)
    .widgetURL(openURL)
  }

  @ViewBuilder
  private func row(_ row: DoseRow) -> some View {
    let label = Text(row.line)
      .font(.title3)
      .lineLimit(2)
      .minimumScaleFactor(0.8)
    if #available(iOS 17.0, *), let dose = row.dose, !entry.taken.isEmpty {
      HStack(spacing: 6) {
        label
        Spacer(minLength: 0)
        Button(intent: MarkDoseTakenIntent(medicineId: dose.m, at: dose.at)) {
          Text(entry.taken)
            .font(.callout)
            .lineLimit(1)
            .fixedSize()
        }
        .buttonStyle(.borderedProminent)
      }
    } else {
      label
    }
  }
}

@main
struct DoseWidget: Widget {
  // Matches HomeWidgetSnapshotPublisher.iOSKind.
  let kind = "DoseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: DoseProvider()) { entry in
      if #available(iOS 17.0, *) {
        DoseWidgetView(entry: entry).containerBackground(.background, for: .widget)
      } else {
        DoseWidgetView(entry: entry)
      }
    }
    .configurationDisplayName(text("widget.title"))
    .description(text("widget.description"))
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
