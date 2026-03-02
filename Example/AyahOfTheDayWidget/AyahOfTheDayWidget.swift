//
//  AyahOfTheDayWidget.swift
//  AyahOfTheDayWidget
//
//  Created by Ibrahim on 24/02/2026.
//

import WidgetKit
import SwiftUI

@main
struct AyahOfTheDayWidget: Widget {
    let kind: String = "AyahOfTheDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            AyahWidgetView(entry: entry)
        }
        .configurationDisplayName("Ayah of the Day")
        .description("Displays a daily Quranic verse.")
        .supportedFamilies([.systemMedium])
    }
}

#Preview(as: .systemMedium) {
    AyahOfTheDayWidget()
} timeline: {
    AyahEntry(date: .now, ayah: Ayah(text: "إِنَّ مَعَ الْعُسْرِ يُسْرًا", surahName: "الشرح", surahNumber: 94, ayahNumber: 6))
}
