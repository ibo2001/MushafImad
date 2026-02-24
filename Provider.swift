import WidgetKit

struct Provider: TimelineProvider {

    private let sampleAyah = Ayah(
        text: "إِنَّ مَعَ الْعُسْرِ يُسْرًا",
        surahName: "الشرح",
        ayahNumber: 6
    )

    func placeholder(in context: Context) -> AyahEntry {
        AyahEntry(date: Date(), ayah: sampleAyah)
    }

    func getSnapshot(in context: Context, completion: @escaping (AyahEntry) -> Void) {
        completion(AyahEntry(date: Date(), ayah: sampleAyah))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahEntry>) -> Void) {

        let entry = AyahEntry(date: Date(), ayah: sampleAyah)
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}
