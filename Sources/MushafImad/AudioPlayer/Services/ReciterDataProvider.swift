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
        ReciterCatalogEntry(id: 9, nameArabic: "أحمد النعينة", nameEnglish: "Ahmad Nauina", rewaya: "حفص عن عاصم", folderURL: "https://server6.mp3quran.net/ahmad_nu/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 10, nameArabic: "أكرم العلاقمي", nameEnglish: "Akram Alalaqmi", rewaya: "حفص عن عاصم", folderURL: "https://server14.mp3quran.net/akrm/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 31, nameArabic: "سعود الشريم", nameEnglish: "Saud Al-Shuraim", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/shur/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 32, nameArabic: "سهل يس", nameEnglish: "Sahl Yassin", rewaya: "حفص عن عاصم", folderURL: "https://server11.mp3quran.net/shl/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 51, nameArabic: "عبدالباسط عبدالصمد", nameEnglish: "Abdulbasit Abdulsamad (Mujawwad)", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/basit_mjwd/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 53, nameArabic: "عبدالباسط عبدالصمد", nameEnglish: "Abdulbasit Abdulsamad", rewaya: "حفص عن عاصم", folderURL: "https://server11.mp3quran.net/basit/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 60, nameArabic: "عبدالله البصفري", nameEnglish: "Abdullah Basfer", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/bsfr/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 62, nameArabic: "عبدالله الجهني", nameEnglish: "Abdullah Al-Johany", rewaya: "حفص عن عاصم", folderURL: "https://server12.mp3quran.net/jhn/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 67, nameArabic: "عبدالمحسن القاسم", nameEnglish: "Abdulmohsen Al-Qasim", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/qasm/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 74, nameArabic: "علي الحذيفي", nameEnglish: "Ali Alhuthaifi", rewaya: "حفص عن عاصم", folderURL: "https://server6.mp3quran.net/hthfi/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 78, nameArabic: "عماد حافظ", nameEnglish: "Emad Hafez", rewaya: "حفص عن عاصم", folderURL: "https://server16.mp3quran.net/hafz/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 106, nameArabic: "محمد جبريل", nameEnglish: "Mohammad Al-Tablaway", rewaya: "حفص عن عاصم", folderURL: "https://server9.mp3quran.net/tblawi/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 112, nameArabic: "محمود علي البنا", nameEnglish: "Al-Minshawi", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/minsh/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 118, nameArabic: "محمود علي الحصري", nameEnglish: "Al-Hussary", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/husr/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 159, nameArabic: "خالد المهنا", nameEnglish: "Khalid Almohana", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/mohna/", timingSource: .mp3quran),
        ReciterCatalogEntry(id: 256, nameArabic: "أحمد شاهين", nameEnglish: "Ahmad Shaheen", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/shaheen/", timingSource: .mp3quran),
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
