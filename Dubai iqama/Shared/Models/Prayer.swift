import Foundation

enum Prayer: String, CaseIterable, Codable {
    case fajr = "Fajr"
    case zuhr = "Zuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"

    var displayName: String { rawValue }

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .zuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    var next: Prayer {
        switch self {
        case .fajr: return .zuhr
        case .zuhr: return .asr
        case .asr: return .maghrib
        case .maghrib: return .isha
        case .isha: return .fajr
        }
    }

    static var orderedPrayers: [Prayer] {
        [.fajr, .zuhr, .asr, .maghrib, .isha]
    }
}
