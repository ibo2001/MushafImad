import WidgetKit
import SwiftUI

@main
struct AyahOfTheDayWidget: Widget {

    let kind: String = "AyahOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: Provider()
        ) { entry in
            AyahWidgetView(entry: entry)
        }
        .configurationDisplayName("آية اليوم")
        .description("تعرض آية من القرآن الكريم كل يوم")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
