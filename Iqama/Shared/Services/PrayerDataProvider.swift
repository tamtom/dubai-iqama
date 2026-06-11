import Foundation

/// A source of monthly prayer-time data. Both the bundled UAE/Awqaf source and the live
/// Aladhan source conform, so `PrayerTimesService` can route between them while every
/// downstream caller keeps working with `PrayerTimesMonthData` / `DailyPrayerTimes`.
protocol PrayerDataProvider {
    /// Stable identifier for the active source, e.g. "awqaf:dubai" or "aladhan:GB-London".
    /// Used as part of the month-cache key so switching source/emirate doesn't serve stale data.
    var sourceID: String { get }

    /// Whether this source carries its own official iqama offsets (Awqaf does, Aladhan doesn't).
    var hasOfficialIqama: Bool { get }

    func monthData(year: Int, month: Int) throws -> PrayerTimesMonthData
}

/// UAE source: reads bundled static Awqaf JSON for one emirate from
/// `prayer_times_2026/<slug>/month_NN.json`. Data is 2026-only.
struct BundledAwqafProvider: PrayerDataProvider {
    let emirate: Emirate

    var sourceID: String { "awqaf:\(emirate.slug)" }
    var hasOfficialIqama: Bool { true }

    func monthData(year: Int, month: Int) throws -> PrayerTimesMonthData {
        let filename = String(format: "month_%02d", month)
        let subdir = "prayer_times_2026/\(emirate.slug)"

        // Folder reference bundles the tree verbatim, so the subdirectory lookup is primary.
        var url = Bundle.main.url(forResource: filename, withExtension: "json", subdirectory: subdir)
        // Fallbacks (older flat layout / Resources-prefixed) just in case.
        if url == nil {
            url = Bundle.main.url(forResource: filename, withExtension: "json",
                                  subdirectory: "Resources/\(subdir)")
        }

        guard let fileURL = url else {
            throw PrayerTimesError.fileNotFound(month: month)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(PrayerTimesMonthData.self, from: data)
        } catch let error as DecodingError {
            throw PrayerTimesError.decodingError(error)
        }
    }
}

extension AzanSettings {
    /// Official UAE Awqaf iqama offsets + prayer durations — the defaults used everywhere,
    /// including non-UAE where Aladhan provides no iqama data.
    static let uaeDefault = AzanSettings(
        fajrIqama: 25, fajrPrayDuration: 10,
        zuhrIqama: 20, zuhrPrayDurarion: 5,
        asrIqama: 20, asrPrayDuration: 5,
        magribIqama: 5, magribPrayDuration: 10,
        ishaIqama: 20, ishaPrayDuration: 5,
        fridayIqama: 20, fridayPrayDuration: 5
    )
}
