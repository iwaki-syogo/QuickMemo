import WidgetKit
import SwiftUI

struct QuickMemoEntry: TimelineEntry {
    let date: Date
}

struct QuickMemoProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickMemoEntry {
        QuickMemoEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickMemoEntry) -> Void) {
        completion(QuickMemoEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickMemoEntry>) -> Void) {
        let entry = QuickMemoEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

struct QuickMemoWidgetEntryView: View {
    var entry: QuickMemoProvider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.square.on.square")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.4))

            Text("新規メモ")
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
        .widgetURL(URL(string: "quickmemo://new"))
    }
}

struct QuickMemoWidget: Widget {
    let kind: String = "QuickMemoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickMemoProvider()) { entry in
            QuickMemoWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("GitMemo")
        .description("タップして新規メモを作成")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    QuickMemoWidget()
} timeline: {
    QuickMemoEntry(date: Date())
}
