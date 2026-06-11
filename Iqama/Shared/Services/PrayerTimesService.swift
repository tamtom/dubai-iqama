import Foundation

enum PrayerTimesError: Error, LocalizedError {
    case fileNotFound(month: Int)
    case invalidDateFormat
    case noPrayerTimesAvailable
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let month):
            return "Prayer times for month \(month) not available"
        case .invalidDateFormat:
            return "Invalid date format in prayer times data"
        case .noPrayerTimesAvailable:
            return "No prayer times available for the requested date"
        case .decodingError(let error):
            return "Failed to decode prayer times: \(error.localizedDescription)"
        }
    }
}

/// Cache key: the same month from different sources (emirate, or Aladhan city) is distinct.
struct MonthKey: Hashable {
    let sourceID: String
    let year: Int
    let month: Int
}

/// Facade over the active `PrayerDataProvider`. Downstream callers (CountdownManager, the
/// widget timeline, the views) use the same methods and types as before — only the source
/// of the monthly data changes underneath, based on the resolved location + settings.
class PrayerTimesService {
    static let shared = PrayerTimesService()

    private var cache: [MonthKey: PrayerTimesMonthData] = [:]
    private let calendar = Calendar.current

    private init() {}

    // MARK: - Active provider

    private var _provider: PrayerDataProvider?

    /// The active source, resolved lazily from settings and memoized. Call `refreshProvider()`
    /// after a location / emirate / source change so the next read re-resolves.
    var provider: PrayerDataProvider {
        if let p = _provider { return p }
        let p = Self.resolveProvider()
        _provider = p
        return p
    }

    /// Chooses the source from settings: UAE → bundled Awqaf for the resolved emirate;
    /// outside the UAE → Aladhan (wired in Step 4). Always returns a usable provider.
    static func resolveProvider() -> PrayerDataProvider {
        if AppSettings.resolvedIsUAE {
            return BundledAwqafProvider(emirate: AppSettings.selectedEmirate)
        }
        let loc = ResolvedLocation.current()
        let method = CalculationMethod.resolved(setting: AppSettings.calcMethod, countryISO: loc.countryISO)
        return AladhanProvider(location: loc, method: method)
    }

    /// Re-resolve the provider and drop cached months. Call when location/source settings change.
    func refreshProvider() {
        _provider = Self.resolveProvider()
        cache.removeAll()
    }

    // MARK: - Data Loading

    func loadMonthData(year: Int, month: Int) throws -> PrayerTimesMonthData {
        let key = MonthKey(sourceID: provider.sourceID, year: year, month: month)
        if let cached = cache[key] { return cached }
        let data = try provider.monthData(year: year, month: month)
        cache[key] = data
        return data
    }

    /// Back-compat: load a month for the current year (used by `preloadMonth`).
    func loadMonthData(for month: Int) throws -> PrayerTimesMonthData {
        try loadMonthData(year: calendar.component(.year, from: Date()), month: month)
    }

    // MARK: - Prayer Time Lookup

    func getPrayerTimes(for date: Date) throws -> DailyPrayerTimes? {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let year = calendar.component(.year, from: date)

        let monthData = try loadMonthData(year: year, month: month)

        return monthData.prayerData.first { dailyTimes in
            guard let gDate = dailyTimes.gregorianDate else { return false }
            return calendar.component(.day, from: gDate) == day
                && calendar.component(.month, from: gDate) == month
                && calendar.component(.year, from: gDate) == year
        }
    }

    func getAzanSettings(for date: Date) throws -> AzanSettings {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let base = try loadMonthData(year: year, month: month).azanSettings
        return effectiveAzanSettings(base: base)
    }

    /// Resolves which iqama offsets to use: the user's custom offsets if enabled, otherwise the
    /// source's official offsets (Awqaf), or the UAE defaults for sources without iqama (Aladhan).
    private func effectiveAzanSettings(base: AzanSettings) -> AzanSettings {
        if AppSettings.customIqamaEnabled {
            return AppSettings.customAzanSettings
        }
        if !provider.hasOfficialIqama {
            return AzanSettings.uaeDefault
        }
        return base
    }

    // MARK: - Next Prayer Calculation

    func getNextPrayerInfo(from date: Date) throws -> (prayer: Prayer, azanTime: Date, iqamaTime: Date, dailyTimes: DailyPrayerTimes)? {
        guard let todayTimes = try getPrayerTimes(for: date) else {
            return nil
        }

        let settings = try getAzanSettings(for: date)

        for prayer in Prayer.orderedPrayers {
            if let azanTime = todayTimes.prayerTime(for: prayer) {
                let iqamaMinutes = settings.iqamaMinutes(for: prayer, isFriday: todayTimes.isFriday)
                let iqamaTime = azanTime.addingTimeInterval(TimeInterval(iqamaMinutes * 60))

                if date < iqamaTime {
                    return (prayer, azanTime, iqamaTime, todayTimes)
                }
            }
        }

        // All prayers passed today → tomorrow's Fajr.
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
        cache.removeAll()
    }

    func preloadMonth(_ month: Int) {
        _ = try? loadMonthData(for: month)
    }
}
