import Foundation

public enum TimingSource: Codable, Equatable, Sendable {
    case mp3quran
    case itqan(assetId: Int)
    case both(itqanAssetId: Int)
    case none
}

public struct ReciterCatalogEntry: Sendable {
    public let id: Int
    public let nameArabic: String
    public let nameEnglish: String
    public let rewaya: String
    public let folderURL: String
    public let timingSource: TimingSource

    public init(
        id: Int,
        nameArabic: String,
        nameEnglish: String,
        rewaya: String,
        folderURL: String,
        timingSource: TimingSource
    ) {
        self.id = id
        self.nameArabic = nameArabic
        self.nameEnglish = nameEnglish
        self.rewaya = rewaya
        self.folderURL = folderURL
        self.timingSource = timingSource
    }
}

public struct ReciterDataProvider {
    public static let reciters: [ReciterCatalogEntry] = [
        ReciterCatalogEntry(id: 1, nameArabic: "إبراهيم الأخضر", nameEnglish: "Ibrahim Al-Akdar", rewaya: "حفص عن عاصم", folderURL: "https://server6.mp3quran.net/akdr/", timingSource: .both(itqanAssetId: 11)),
        ReciterCatalogEntry(id: 5, nameArabic: "أحمد بن علي العجمي", nameEnglish: "Ahmad Al-Ajmy", rewaya: "حفص عن عاصم", folderURL: "https://server10.mp3quran.net/ajm/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 9, nameArabic: "محمود خليل الحصري", nameEnglish: "Mahmoud Khalil Al-Hussary", rewaya: "حفص عن عاصم", folderURL: "https://server13.mp3quran.net/husr/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 10, nameArabic: "علي بن عبدالرحمن الحذيفي", nameEnglish: "Ali Abdur-Rahman al-Huthaify", rewaya: "حفص عن عاصم", folderURL: "https://server14.mp3quran.net/hthfi/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 31, nameArabic: "سعود الشريم", nameEnglish: "Saud Al-Shuraim", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/shur/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 32, nameArabic: "عبدالرحمن السديس", nameEnglish: "Abdul Rahman Al-Sudais", rewaya: "حفص عن عاصم", folderURL: "https://server11.mp3quran.net/sds/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 51, nameArabic: "بندر بليلة", nameEnglish: "Bandar Baleela", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/balilah/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 53, nameArabic: "ياسر الدوسري", nameEnglish: "Yasser Al-Dosari", rewaya: "حفص عن عاصم", folderURL: "https://server11.mp3quran.net/dosri/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 60, nameArabic: "فارس عباد", nameEnglish: "Fares Abbad", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/frs_a/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 62, nameArabic: "ماهر المعيقلي", nameEnglish: "Maher Al Mueaqly", rewaya: "حفص عن عاصم", folderURL: "https://server12.mp3quran.net/maher/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 67, nameArabic: "عبدالله بصفر", nameEnglish: "Abdullah Basfar", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/basit/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 74, nameArabic: "ناصر القطامي", nameEnglish: "Nasser Al Qatami", rewaya: "حفص عن عاصم", folderURL: "https://server6.mp3quran.net/qtm/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 78, nameArabic: "محمد أيوب", nameEnglish: "Muhammad Ayyub", rewaya: "حفص عن عاصم", folderURL: "https://server16.mp3quran.net/ayyub2/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 106, nameArabic: "عمر القزابري", nameEnglish: "Omar Al-Qazabri", rewaya: "ورش عن نافع", folderURL: "https://server9.mp3quran.net/omar_warsh/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 112, nameArabic: "مشاري العفاسي", nameEnglish: "Mishari Rashid al-`Afasy", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/afs/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 118, nameArabic: "محمد جبريل", nameEnglish: "Mohammad al Tablaway", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/jbrl/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 159, nameArabic: "عبدالباسط عبدالصمد", nameEnglish: "Abdul Basit Abdus Samad", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/basit_mjwd/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 256, nameArabic: "هاني الرفاعي", nameEnglish: "Hani Ar-Rifai", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/hani/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 1001, nameArabic: "بدر التركي", nameEnglish: "Badr Al-Turki", rewaya: "حفص عن عاصم", folderURL: "https://api.cms.itqan.dev/", timingSource: .itqan(assetId: 11)),
        ReciterCatalogEntry(id: 1002, nameArabic: "ماجد الزامل", nameEnglish: "Majed Al-Zamil", rewaya: "حفص عن عاصم", folderURL: "https://api.cms.itqan.dev/", timingSource: .itqan(assetId: 12))
    ]

    public static func getReciterInfo(id: Int) -> (nameArabic: String, nameEnglish: String, rewaya: String, folderURL: String, timingSource: TimingSource)? {
        reciters.first { $0.id == id }.map {
            (
                nameArabic: $0.nameArabic,
                nameEnglish: $0.nameEnglish,
                rewaya: $0.rewaya,
                folderURL: $0.folderURL,
                timingSource: $0.timingSource
            )
        }
    }

    public static func timingSource(for id: Int) -> TimingSource {
        reciters.first { $0.id == id }?.timingSource ?? .mp3quran
    }

    public static func itqanAssetId(for id: Int) -> Int? {
        switch timingSource(for: id) {
        case let .itqan(assetId):
            return assetId
        case let .both(itqanAssetId):
            return itqanAssetId
        default:
            return nil
        }
    }
}
