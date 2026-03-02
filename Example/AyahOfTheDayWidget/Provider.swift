import WidgetKit
import MushafImad

struct Provider: TimelineProvider {

    // Provide a static fallback for synchronous placeholder and errors
    private func fallbackAyah(errorMsg: String? = nil) -> Ayah {
        return Ayah(text: errorMsg ?? "إِنَّ مَعَ الْعُسْرِ يُسْرًا", surahName: "الشرح", surahNumber: 94, ayahNumber: 6)
    }

    // اختيار آية بناءً على التاريخ
    @MainActor
    private func fetchAyahForDate(_ date: Date) -> Ayah {
        // Ensure realm is initialized before fetching
        do {
            try RealmService.shared.initializeForWidget()
            
            if let verse = RealmService.shared.getRandomAyah(for: date),
               let chapter = verse.chapter {
                return Ayah(
                    text: verse.textWithoutTashkil.isEmpty ? verse.text : verse.textWithoutTashkil,
                    surahName: chapter.arabicTitle,
                    surahNumber: chapter.number,
                    ayahNumber: verse.number
                )
            }
            return fallbackAyah(errorMsg: "getRandomAyah returned nil")
        } catch {
            return fallbackAyah(errorMsg: error.localizedDescription)
        }
    }

    func placeholder(in context: Context) -> AyahEntry {
        // Placeholders must be returned synchronously
        AyahEntry(date: Date(), ayah: fallbackAyah())
    }

    func getSnapshot(in context: Context, completion: @escaping (AyahEntry) -> Void) {
        if context.isPreview {
            completion(AyahEntry(date: Date(), ayah: fallbackAyah()))
            return
        }
        
        Task { @MainActor in
            let ayah = fetchAyahForDate(Date())
            completion(AyahEntry(date: Date(), ayah: ayah))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AyahEntry>) -> Void) {
        Task { @MainActor in
            let date = Date()
            let entry = AyahEntry(date: date, ayah: fetchAyahForDate(date))

            // تحديث عند منتصف الليل
            let nextUpdate = Calendar.current.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) ?? date.addingTimeInterval(86400)

            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}
