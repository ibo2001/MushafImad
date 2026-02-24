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
        .configurationDisplayName(
            String(localized: "AyahOfTheDay.displayName")
        )
        .description(
            String(localized: "AyahOfTheDay.description")
        )
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}