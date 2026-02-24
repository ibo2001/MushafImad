import WidgetKit

struct Provider: TimelineProvider {

    // آيات تجريبية (ديناميكية بسيطة)
    private let sampleAyat: [Ayah] = [
        Ayah(text: "إِنَّ مَعَ الْعُسْرِ يُسْرًا", surahName: "الشرح", ayahNumber: 6),
        Ayah(text: "أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ", surahName: "الرعد", ayahNumber: 28),
        Ayah(text: "فَاذْكُرُونِي أَذْكُرْكُمْ", surahName: "البقرة", ayahNumber: 152)
    ]

    // اختيار آية عشوائية
    private func randomAyah() -> Ayah {
        sampleAyat.randomElement() ?? sampleAyat[0]
    }

    func placeholder(in context: Context) -> AyahEntry {
        AyahEntry(date: Date(), ayah: randomAyah())
    }

    func getSnapshot(in context: Context, completion: @escaping (AyahEntry) -> Void) {
        completion(AyahEntry(date: Date(), ayah: randomAyah()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahEntry>) -> Void) {

        let entry = AyahEntry(date: Date(), ayah: randomAyah())

        // تحديث آمن بدون force unwrap
        let nextUpdate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}