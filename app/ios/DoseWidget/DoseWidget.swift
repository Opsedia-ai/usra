// Home-screen widget: the next three doses today across the family.
//
// NOT BUILT YET: written without Xcode. Add the extension target and the
// App Group as README.md in this folder says, then build and try it.
//
// The database is encrypted, so the widget never reads it: the app saves a
// small snapshot (first names, medicine names, times; see
// `lib/features/medicines/dose_widget.dart`) in the App Group, and the
// widget picks the next three doses as time passes, rolling over at
// midnight without the app. Tapping it opens the Medicines tab.

import SwiftUI
import WidgetKit

private let appGroup = "group.com.opsedia.usra"
private let dataKey = "dose_widget_snapshot"
private let openURL = URL(string: "usra://widget/medicines?homeWidget")!
private let shown = 3

struct WidgetDose: Decodable {
  let at: Int64
  let time: String
  let person: String
  let medicine: String
  let m: String

  var date: Date { Date(timeIntervalSince1970: TimeInterval(at) / 1000) }
  var line: String { "\(time) · \(person) · \(medicine)" }
}

struct WidgetSnapshot: Decodable {
  let v: Int
  let generatedAt: Int64
  let validUntil: Int64
  let graceMinutes: Int
  let rtl: Bool
  let title: String
  let empty: String
  let stale: String
  let doses: [WidgetDose]

  var validUntilDate: Date { Date(timeIntervalSince1970: TimeInterval(validUntil) / 1000) }
  var grace: TimeInterval { TimeInterval(graceMinutes * 60) }

  static func load() -> WidgetSnapshot? {
    guard let raw = UserDefaults(suiteName: appGroup)?.string(forKey: dataKey),
      let data = raw.data(using: .utf8),
      let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data),
      snapshot.v == 1
    else { return nil }
    return snapshot
  }
}

struct DoseEntry: TimelineEntry {
  let date: Date
  let title: String
  let rtl: Bool
  let lines: [String]
  /// Shown when there are no doses: nothing today, or open the app.
  let message: String
}

struct DoseProvider: TimelineProvider {
  func placeholder(in context: Context) -> DoseEntry {
    DoseEntry(
      date: Date(), title: "أدوية النهارده", rtl: true,
      lines: ["٨:٠٠ م · عمر · باراسيتامول"], message: "")
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
        times.insert(d.date.addingTimeInterval(s.grace))
      }
    }
    let end = calendar.date(byAdding: .day, value: 1, to: tomorrow)!
    let entries = times.filter { $0 >= now && $0 <= end }.sorted().map { entry(at: $0, snapshot) }
    completion(Timeline(entries: entries, policy: .after(tomorrow)))
  }

  private func entry(at date: Date, _ snapshot: WidgetSnapshot?) -> DoseEntry {
    guard let s = snapshot, date < s.validUntilDate else {
      return DoseEntry(
        date: date, title: snapshot?.title ?? "أدوية النهارده", rtl: snapshot?.rtl ?? true,
        lines: [], message: snapshot?.stale ?? "افتح أسرة عشان نحدّث الأدوية")
    }
    let calendar = Calendar.current
    let due = s.doses.filter {
      $0.date >= date.addingTimeInterval(-s.grace) && calendar.isDate($0.date, inSameDayAs: date)
    }
    return DoseEntry(
      date: date, title: s.title, rtl: s.rtl,
      lines: due.prefix(shown).map(\.line), message: s.empty)
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
      if entry.lines.isEmpty {
        Text(entry.message)
          .font(.title3)
      } else {
        ForEach(Array(entry.lines.prefix(family == .systemSmall ? 2 : shown).enumerated()), id: \.offset) {
          Text($0.element)
            .font(.title3)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
        }
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding()
    .environment(\.layoutDirection, entry.rtl ? .rightToLeft : .leftToRight)
    .widgetURL(openURL)
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
    .configurationDisplayName("أدوية النهارده")
    .description("مواعيد الأدوية الجاية للعيلة")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}
