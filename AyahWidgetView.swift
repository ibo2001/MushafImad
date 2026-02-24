import SwiftUI
import WidgetKit

struct AyahWidgetView: View {

    let entry: AyahEntry

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {

            Text(entry.ayah.text)
                .font(.system(size: 16, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .lineLimit(4)

            Spacer(minLength: 4)

            Text("\(entry.ayah.surahName) • \(entry.ayah.ayahNumber)")
                .font(.caption)
                .foregroundColor(.secondary)

        }
        .padding()
        .environment(\.layoutDirection, .rightToLeft)
        .background(Color(.systemBackground))
        .widgetURL(URL(string: "mushaf://ayah/6"))
    }
}
