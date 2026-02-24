import SwiftUI
import WidgetKit

struct AyahWidgetView: View {

    let entry: AyahEntry

    var body: some View {
        if let url = URL(string: "mushafimad://ayah/\(entry.ayah.ayahNumber)") {
            VStack(alignment: .trailing, spacing: 8) {

                Text(entry.ayah.text)
                    .font(.custom("KitabBold", size: 16))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(4)

                Spacer(minLength: 4)

                Text("\(entry.ayah.surahName) • \(entry.ayah.ayahNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)

            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
            .containerBackground(.background, for: .widget)
            .widgetURL(url)
        }
    }
}