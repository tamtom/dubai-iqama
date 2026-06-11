import Foundation

// Minimal Decodable mirror of the Aladhan `calendar` / `calendarByCity` month response.
// https://api.aladhan.com/v1/calendarByCity/{year}/{month}?city=&country=&method=N

struct AladhanMonthResponse: Decodable {
    let code: Int
    let data: [AladhanDay]
}

struct AladhanDay: Decodable {
    let timings: AladhanTimings
    let date: AladhanDate
    let meta: AladhanMeta
}

struct AladhanTimings: Decodable {
    let fajr, sunrise, dhuhr, asr, maghrib, isha, imsak: String
    enum CodingKeys: String, CodingKey {
        case fajr = "Fajr", sunrise = "Sunrise", dhuhr = "Dhuhr", asr = "Asr"
        case maghrib = "Maghrib", isha = "Isha", imsak = "Imsak"
    }
}

struct AladhanDate: Decodable {
    let gregorian: AladhanGregorian
    let hijri: AladhanHijri
}

struct AladhanGregorian: Decodable {
    let date: String          // "DD-MM-YYYY"
    let weekday: AladhanNamePair
    let month: AladhanMonthInfo
    let year: String
}

struct AladhanHijri: Decodable {
    let day: String
    let month: AladhanMonthInfo
    let year: String
}

struct AladhanNamePair: Decodable { let en: String }
struct AladhanMonthInfo: Decodable { let number: Int; let en: String; let ar: String? }
struct AladhanMeta: Decodable { let timezone: String }

/// Aladhan calculation methods. Auto-picks a sensible default per ISO country, overridable in
/// Settings. Ints match Aladhan's `method` query parameter.
enum CalculationMethod {
    static let autoValue = -1

    /// Picker options (value, label). `autoValue` first.
    static let options: [(value: Int, label: String)] = [
        (-1, "Auto (by country)"),
        (3, "Muslim World League"),
        (4, "Umm al-Qura (Makkah)"),
        (5, "Egyptian General Authority"),
        (2, "Islamic Society of North America"),
        (1, "University of Karachi"),
        (8, "Gulf Region"),
        (9, "Kuwait"),
        (10, "Qatar"),
        (16, "Dubai"),
        (13, "Diyanet (Turkey)"),
        (12, "Union des Org. Islamiques (France)"),
        (15, "Moonsighting Committee Worldwide"),
        (0, "Shia Ithna-Ashari"),
    ]

    static func label(for value: Int) -> String {
        options.first { $0.value == value }?.label ?? "Auto (by country)"
    }

    /// Resolve the effective Aladhan method int. If the user picked a specific method, use it;
    /// otherwise auto-pick from the country.
    static func resolved(setting: Int, countryISO: String?) -> Int {
        if setting != autoValue { return setting }
        return autoMethod(forCountry: countryISO)
    }

    static func autoMethod(forCountry iso: String?) -> Int {
        guard let iso = iso?.uppercased() else { return 3 } // MWL fallback
        switch iso {
        case "SA", "YE", "BH", "OM": return 4   // Umm al-Qura
        case "AE": return 16                      // Dubai
        case "KW": return 9
        case "QA": return 10
        case "EG", "SD", "SY", "IQ", "LB", "PS", "LY": return 5 // Egyptian
        case "JO": return 23
        case "US", "CA": return 2                 // ISNA
        case "PK", "IN", "BD", "AF", "LK": return 1 // Karachi
        case "TR": return 13
        case "RU": return 14
        case "SG": return 11
        case "MY": return 17
        case "ID": return 20
        case "FR": return 12
        case "MA": return 21
        case "TN": return 18
        case "DZ": return 19
        case "IR": return 7
        default: return 3                         // Muslim World League
        }
    }
}
