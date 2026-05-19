import WidgetKit
import SwiftUI

// MARK: - Entry

struct QuickEntry: TimelineEntry {
    let date: Date
    let actionLabel: String
}

// MARK: - Provider

struct QuickAccessProvider: TimelineProvider {

    func placeholder(in context: Context) -> QuickEntry {
        QuickEntry(date: Date(), actionLabel: "Open CashMind")
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickEntry) -> Void) {
        completion(QuickEntry(date: Date(), actionLabel: label()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickEntry>) -> Void) {
        let now = Date()
        let entry = QuickEntry(date: now, actionLabel: label())
        // Refresh раз в час — достаточно для greeting-обновления
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func label() -> String {
        let isRu = (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("ru")
        let hour = Calendar.current.component(.hour, from: Date())
        if isRu {
            if hour < 12 { return "Утренний бюджет" }
            if hour < 18 { return "Дневные расходы" }
            return "Вечерний итог"
        } else {
            if hour < 12 { return "Morning Budget" }
            if hour < 18 { return "Today's Expenses" }
            return "Evening Recap"
        }
    }
}

// MARK: - View

struct QuickAccessWidgetView: View {

    let entry: QuickEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Gradient background соответствующий бренду
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.37, green: 0.62, blue: 0.63),  // #5F9EA0 accent
                    Color(red: 0.09, green: 0.09, blue: 0.09)   // #171717 background
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: family == .systemSmall ? 4 : 8) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: family == .systemSmall ? 28 : 36, weight: .medium))
                    .foregroundStyle(.white)

                Text("CashMind")
                    .font(.system(size: family == .systemSmall ? 15 : 18, weight: .bold))
                    .foregroundStyle(.white)

                Text(entry.actionLabel)
                    .font(.system(size: family == .systemSmall ? 11 : 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(family == .systemSmall ? 8 : 16)
        }
        .widgetURL(URL(string: "cashmind://open"))
    }
}

// MARK: - Widget

struct QuickAccessWidget: Widget {
    let kind: String = "CashMindQuickAccess"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAccessProvider()) { entry in
            if #available(iOS 17.0, *) {
                QuickAccessWidgetView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                QuickAccessWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("CashMind")
        .description("Quick access to your personal finances.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview(as: .systemSmall) {
    QuickAccessWidget()
} timeline: {
    QuickEntry(date: .now, actionLabel: "Morning Budget")
}
#endif
