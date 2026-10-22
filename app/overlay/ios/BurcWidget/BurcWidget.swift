// Günlük Burç - kilit ekranı ve ana ekran widget'ı (iOS 16+)
// Xcode'da "Widget Extension" hedefi olarak eklenir; App Group: group.com.alisimseker.gunlukburc
import SwiftUI
import WidgetKit

private let kAppGroup = "group.com.alisimseker.gunlukburc"
private let kSymbols: [String: String] = [
  "koc": "♈", "boga": "♉", "ikizler": "♊", "yengec": "♋", "aslan": "♌", "basak": "♍",
  "terazi": "♎", "akrep": "♏", "yay": "♐", "oglak": "♑", "kova": "♒", "balik": "♓",
]

struct BurcEntry: TimelineEntry {
  let date: Date
  let symbol: String
  let name: String
  let short: String
  let motivation: String
  let ready: Bool
}

struct BurcProvider: TimelineProvider {
  private var shared: UserDefaults { UserDefaults(suiteName: kAppGroup) ?? .standard }

  func placeholder(in context: Context) -> BurcEntry {
    BurcEntry(date: Date(), symbol: "♏", name: "Akrep", short: "Bugün küçük bir adım büyük bir kapı açabilir.",
              motivation: "Önce kendine inan", ready: true)
  }

  func getSnapshot(in context: Context, completion: @escaping (BurcEntry) -> Void) {
    completion(entries(from: shared.data(forKey: "cache")).first ?? placeholder(in: context))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BurcEntry>) -> Void) {
    // Önce internetten tazelemeyi dene (uygulama kapalı olsa bile), olmazsa önbelleği kullan
    guard let sign = shared.string(forKey: "sign"), let base = shared.string(forKey: "baseUrl"),
          let url = URL(string: "\(base)/v1/\(sign).json?t=\(Int(Date().timeIntervalSince1970) / 600)")
    else {
      completion(Timeline(entries: [notReady()], policy: .after(Date().addingTimeInterval(3600))))
      return
    }
    var req = URLRequest(url: url)
    req.cachePolicy = .reloadIgnoringLocalCacheData
    req.timeoutInterval = 12
    URLSession.shared.dataTask(with: req) { data, resp, _ in
      if let data = data, (resp as? HTTPURLResponse)?.statusCode == 200,
         (try? JSONSerialization.jsonObject(with: data)) != nil {
        shared.set(data, forKey: "cache")
      }
      var list = entries(from: shared.data(forKey: "cache"))
      if list.isEmpty { list = [notReady()] }
      // 4 saatte bir tekrar dene; gün değişimlerinde hazır kayıtlar zaten sırayla gösterilir
      completion(Timeline(entries: list, policy: .after(Date().addingTimeInterval(4 * 3600))))
    }.resume()
  }

  private func notReady() -> BurcEntry {
    BurcEntry(date: Date(), symbol: "✨", name: "Burç Atlası", short: "Burcunu seçmek için uygulamayı aç.",
              motivation: "Burç Atlası", ready: false)
  }

  /// Bugün ve sonraki günler için, her biri o günün 00:00'ında başlayan kayıtlar.
  private func entries(from data: Data?) -> [BurcEntry] {
    guard let data = data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let days = json["days"] as? [[String: Any]] else { return [] }
    let sign = json["sign"] as? String ?? ""
    let name = json["name"] as? String ?? ""
    let fmt = DateFormatter()
    fmt.calendar = Calendar(identifier: .gregorian)
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.timeZone = .current
    fmt.dateFormat = "yyyy-MM-dd"
    let todayStart = Calendar.current.startOfDay(for: Date())
    var out: [BurcEntry] = []
    for d in days {
      guard let iso = d["date"] as? String, let day = fmt.date(from: iso) else { continue }
      let start = Calendar.current.startOfDay(for: day)
      if start < todayStart { continue }
      out.append(BurcEntry(date: start == todayStart ? Date() : start,
                           symbol: kSymbols[sign] ?? "✨", name: name,
                           short: d["short"] as? String ?? "",
                           motivation: d["motivation"] as? String ?? "", ready: true))
    }
    return out
  }
}

struct BurcWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: BurcEntry

  var body: some View {
    switch family {
    case .accessoryInline:
      // Saatin üstündeki tek satır
      Text("\(entry.symbol) \(entry.motivation)")
    case .accessoryRectangular:
      // Saatin altındaki alan
      VStack(alignment: .leading, spacing: 1) {
        Text("\(entry.symbol) \(entry.motivation)")
          .font(.system(size: 14, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .widgetAccentable()
        Text(entry.short)
          .font(.system(size: 12))
          .lineLimit(2)
          .minimumScaleFactor(0.85)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    default:
      VStack(alignment: .leading, spacing: 6) {
        Text("\(entry.symbol) \(entry.name)").font(.caption).foregroundColor(Color(red: 0.91, green: 0.78, blue: 0.48))
        Text(entry.motivation).font(.headline).foregroundColor(.white).lineLimit(2)
        Text(entry.short).font(.caption).foregroundColor(.white.opacity(0.85)).lineLimit(4)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
  }
}

private extension View {
  @ViewBuilder func widgetBackground(_ family: WidgetFamily) -> some View {
    let color = Color(red: 0.07, green: 0.06, blue: 0.12)
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) {
        if family == .systemSmall || family == .systemMedium { color } else { Color.clear }
      }
    } else if family == .systemSmall || family == .systemMedium {
      padding().background(color)
    } else {
      self
    }
  }
}

@main
struct BurcWidget: Widget {
  let kind = "BurcWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: BurcProvider()) { entry in
      BurcFamilyView(entry: entry)
    }
    .configurationDisplayName("Burç Atlası")
    .description("Günün yorumu ve motivasyon cümlen.")
    .supportedFamilies([.accessoryRectangular, .accessoryInline, .systemSmall, .systemMedium])
  }
}

private struct BurcFamilyView: View {
  @Environment(\.widgetFamily) var family
  let entry: BurcEntry
  var body: some View {
    BurcWidgetView(entry: entry).widgetBackground(family)
  }
}
