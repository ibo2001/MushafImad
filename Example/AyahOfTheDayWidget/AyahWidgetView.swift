import SwiftUI
import WidgetKit

struct AyahWidgetView: View {

    let entry: AyahEntry

    var body: some View {
        let url = URL(string: "mushafimad://ayah/\(entry.ayah.surahNumber)/\(entry.ayah.ayahNumber)")
        
        ZStack {
            VStack(spacing: 8) {

                Text(entry.ayah.text)
                    .font(.custom("Kitab-Bold", size: 16))
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.4)

                Text("\(entry.ayah.surahName) • \(entry.ayah.ayahNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

            }
            .environment(\.layoutDirection, .rightToLeft)
            .padding()
        }
        .containerBackground(.background, for: .widget)
        .widgetURL(url)
    }
}
