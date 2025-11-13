import Foundation

// Temporary data provider until JSON files are added to Xcode project
public struct ReciterDataProvider {
    public static let reciters: [(id: Int, nameArabic: String, nameEnglish: String, rewaya: String, folderURL: String)] = [
        (id: 1, nameArabic: "إبراهيم الأخضر", nameEnglish: "Ibrahim Al-Akdar", rewaya: "حفص عن عاصم", folderURL: "https://server6.mp3quran.net/akdr/"),
        (id: 5, nameArabic: "أحمد بن علي العجمي", nameEnglish: "Ahmad Al-Ajmy", rewaya: "حفص عن عاصم", folderURL: "https://server10.mp3quran.net/ajm/"),
        (id: 9, nameArabic: "محمود خليل الحصري", nameEnglish: "Mahmoud Khalil Al-Hussary", rewaya: "حفص عن عاصم", folderURL: "https://server13.mp3quran.net/husr/"),
        (id: 10, nameArabic: "علي بن عبدالرحمن الحذيفي", nameEnglish: "Ali Abdur-Rahman al-Huthaify", rewaya: "حفص عن عاصم", folderURL: "https://server14.mp3quran.net/hthfi/"),
        (id: 31, nameArabic: "سعود الشريم", nameEnglish: "Saud Al-Shuraim", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/shur/"),
        (id: 32, nameArabic: "عبدالرحمن السديس", nameEnglish: "Abdul Rahman Al-Sudais", rewaya: "حفص عن عاصم", folderURL: "https://server11.mp3quran.net/sds/"),
        (id: 51, nameArabic: "بندر بليلة", nameEnglish: "Bandar Baleela", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/balilah/"),
        (id: 53, nameArabic: "ياسر الدوسري", nameEnglish: "Yasser Al-Dosari", rewaya: "حفص عن عاصم", folderURL: "https://server11.mp3quran.net/dosri/"),
        (id: 60, nameArabic: "فارس عباد", nameEnglish: "Fares Abbad", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/frs_a/"),
        (id: 62, nameArabic: "ماهر المعيقلي", nameEnglish: "Maher Al Mueaqly", rewaya: "حفص عن عاصم", folderURL: "https://server12.mp3quran.net/maher/"),
        (id: 67, nameArabic: "عبدالله بصفر", nameEnglish: "Abdullah Basfar", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/basit/"),
        (id: 74, nameArabic: "ناصر القطامي", nameEnglish: "Nasser Al Qatami", rewaya: "حفص عن عاصم", folderURL: "https://server6.mp3quran.net/qtm/"),
        (id: 78, nameArabic: "محمد أيوب", nameEnglish: "Muhammad Ayyub", rewaya: "حفص عن عاصم", folderURL: "https://server16.mp3quran.net/ayyub2/"),
        (id: 106, nameArabic: "عمر القزابري", nameEnglish: "Omar Al-Qazabri", rewaya: "ورش عن نافع", folderURL: "https://server9.mp3quran.net/omar_warsh/"),
        (id: 112, nameArabic: "مشاري العفاسي", nameEnglish: "Mishari Rashid al-`Afasy", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/afs/"),
        (id: 118, nameArabic: "محمد جبريل", nameEnglish: "Mohammad al Tablaway", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/jbrl/"),
        (id: 159, nameArabic: "عبدالباسط عبدالصمد", nameEnglish: "Abdul Basit Abdus Samad", rewaya: "حفص عن عاصم", folderURL: "https://server7.mp3quran.net/basit_mjwd/"),
        (id: 256, nameArabic: "هاني الرفاعي", nameEnglish: "Hani Ar-Rifai", rewaya: "حفص عن عاصم", folderURL: "https://server8.mp3quran.net/hani/")
    ]
    
    public static func getReciterInfo(id: Int) -> (nameArabic: String, nameEnglish: String, rewaya: String, folderURL: String)? {
        return reciters.first { $0.id == id }.map { (nameArabic: $0.nameArabic, nameEnglish: $0.nameEnglish, rewaya: $0.rewaya, folderURL: $0.folderURL) }
    }
}
