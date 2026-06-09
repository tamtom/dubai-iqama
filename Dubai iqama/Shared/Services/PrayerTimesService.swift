import Foundation

enum PrayerTimesError: Error, LocalizedError {
    case fileNotFound(month: Int)
    case invalidDateFormat
    case noPrayerTimesAvailable
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let month):
            return "Prayer times file for month \(month) not found"
        case .invalidDateFormat:
            return "Invalid date format in prayer times data"
        case .noPrayerTimesAvailable:
            return "No prayer times available for the requested date"
        case .decodingError(let error):
            return "Failed to decode prayer times: \(error.localizedDescription)"
        }
    }
}

class PrayerTimesService {
    static let shared = PrayerTimesService()

    private var cachedMonthData: [Int: PrayerTimesMonthData] = [:]
    private let calendar = Calendar.current

    private init() {}

    // MARK: - Data Loading

    func loadMonthData(for month: Int) throws -> PrayerTimesMonthData {
        if let cached = cachedMonthData[month] {
            return cached
        }

        let filename = String(format: "month_%02d", month)

        // Try multiple loading strategies
        var url: URL?

        // Strategy 1: Folder reference (blue folder in Xcode)
        url = Bundle.main.url(forResource: filename,
                              withExtension: "json",
                              subdirectory: "prayer_times_2026")

        // Strategy 2: Files at root level (yellow group in Xcode)
        if url == nil {
            url = Bundle.main.url(forResource: filename, withExtension: "json")
        }

        // Strategy 3: Look in Resources folder
        if url == nil {
            url = Bundle.main.url(forResource: filename,
                                  withExtension: "json",
                                  subdirectory: "Resources/prayer_times_2026")
        }

        guard let fileURL = url else {
            print("DEBUG: Could not find \(filename).json in bundle")
            print("DEBUG: Bundle path: \(Bundle.main.bundlePath)")
            throw PrayerTimesError.fileNotFound(month: month)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let monthData = try decoder.decode(PrayerTimesMonthData.self, from: data)
            cachedMonthData[month] = monthData
            return monthData
        } catch let error as DecodingError {
            print("DEBUG: Decoding error: \(error)")
            throw PrayerTimesError.decodingError(error)
        }
    }

    // MARK: - Prayer Time Lookup

    func getPrayerTimes(for date: Date) throws -> DailyPrayerTimes? {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let year = calendar.component(.year, from: date)

        let monthData = try loadMonthData(for: month)

        return monthData.prayerData.first { dailyTimes in
            guard let gDate = dailyTimes.gregorianDate else { return false }
            let gDay = calendar.component(.day, from: gDate)
            let gMonth = calendar.component(.month, from: gDate)
            let gYear = calendar.component(.year, from: gDate)
            return gDay == day && gMonth == month && gYear == year
        }
    }

    func getAzanSettings(for date: Date) throws -> AzanSettings {
        let month = calendar.component(.month, from: date)
        let monthData = try loadMonthData(for: month)
        return monthData.azanSettings
    }

    // MARK: - Next Prayer Calculation

    func getNextPrayerInfo(from date: Date) throws -> (prayer: Prayer, azanTime: Date, iqamaTime: Date, dailyTimes: DailyPrayerTimes)? {
        guard let todayTimes = try getPrayerTimes(for: date) else {
            return nil
        }

        let settings = try getAzanSettings(for: date)

        // Check each prayer in order for today
        for prayer in Prayer.orderedPrayers {
            if let azanTime = todayTimes.prayerTime(for: prayer) {
                let iqamaMinutes = settings.iqamaMinutes(for: prayer, isFriday: todayTimes.isFriday)
                let iqamaTime = azanTime.addingTimeInterval(TimeInterval(iqamaMinutes * 60))

                // If we haven't passed the iqama time yet, this is our current/next prayer
                if date < iqamaTime {
                    return (prayer, azanTime, iqamaTime, todayTimes)
                }
            }
        }

        // All prayers passed today, get tomorrow's Fajr
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date),
              let tomorrowTimes = try getPrayerTimes(for: tomorrow),
              let fajrTime = tomorrowTimes.prayerTime(for: .fajr) else {
            return nil
        }

        let tomorrowSettings = try getAzanSettings(for: tomorrow)
        let iqamaMinutes = tomorrowSettings.iqamaMinutes(for: .fajr, isFriday: tomorrowTimes.isFriday)
        let iqamaTime = fajrTime.addingTimeInterval(TimeInterval(iqamaMinutes * 60))

        return (.fajr, fajrTime, iqamaTime, tomorrowTimes)
    }

    // MARK: - Get All Prayer Times for a Day

    func getAllPrayerTimes(for date: Date) throws -> [(prayer: Prayer, azanTime: Date, iqamaTime: Date)]? {
        guard let dailyTimes = try getPrayerTimes(for: date) else {
            return nil
        }

        let settings = try getAzanSettings(for: date)
        var result: [(Prayer, Date, Date)] = []

        for prayer in Prayer.orderedPrayers {
            if let azanTime = dailyTimes.prayerTime(for: prayer) {
                let iqamaMinutes = settings.iqamaMinutes(for: prayer, isFriday: dailyTimes.isFriday)
                let iqamaTime = azanTime.addingTimeInterval(TimeInterval(iqamaMinutes * 60))
                result.append((prayer, azanTime, iqamaTime))
            }
        }

        return result
    }

    // MARK: - Cache Management

    func clearCache() {
        cachedMonthData.removeAll()
    }

    func preloadMonth(_ month: Int) {
        try? _ = loadMonthData(for: month)
    }
}
