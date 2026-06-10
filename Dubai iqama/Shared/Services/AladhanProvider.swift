import Foundation

/// A resolved place the app shows prayer times for. Persisted to the shared App Group defaults
/// so the widget and offline launches see the same selection.
struct ResolvedLocation: Codable, Equatable {
    var isUAE: Bool
    var emirate: Emirate?          // when isUAE
    var countryISO: String?        // ISO-3166 alpha-2 (e.g. "GB")
    var countryName: String?
    var city: String?
    var latitude: Double?
    var longitude: Double?
    var timeZoneID: String?

    static let defaultUAE = ResolvedLocation(
        isUAE: true, emirate: .dubai, countryISO: "AE", countryName: "United Arab Emirates",
        city: "Dubai", latitude: Emirate.dubai.latitude, longitude: Emirate.dubai.longitude,
        timeZoneID: "Asia/Dubai")

    /// Build the current resolved location from settings (what location/source to use now).
    static func current() -> ResolvedLocation {
        if AppSettings.resolvedIsUAE {
            return ResolvedLocation(
                isUAE: true, emirate: AppSettings.selectedEmirate, countryISO: "AE",
                countryName: "United Arab Emirates", city: AppSettings.selectedEmirate.nameEn,
                latitude: AppSettings.selectedEmirate.latitude,
                longitude: AppSettings.selectedEmirate.longitude, timeZoneID: "Asia/Dubai")
        }
        let iso = AppSettings.selectedCountryISO
        return ResolvedLocation(
            isUAE: false, emirate: nil,
            countryISO: iso,
            countryName: iso.flatMap { Locale.current.localizedString(forRegionCode: $0) },
            city: AppSettings.selectedCity,
            latitude: AppSettings.selectedLatitude, longitude: AppSettings.selectedLongitude,
            timeZoneID: AppSettings.selectedTimeZone)
    }
}

/// Non-UAE source: serves pre-mapped Aladhan month data from the App Group disk cache. It NEVER
/// performs network I/O (the provider must be synchronous and the widget is sandboxed) — the main
/// app's `AladhanSync` is the only fetcher/writer. Iqama offsets come from settings, not Aladhan.
struct AladhanProvider: PrayerDataProvider {
    let location: ResolvedLocation
    let method: Int

    var hasOfficialIqama: Bool { false }

    var sourceID: String {
        let country = (location.countryISO ?? "XX").uppercased()
        let city = (location.city ?? "loc")
            .lowercased().replacingOccurrences(of: " ", with: "-")
        return "aladhan:\(country)-\(city)-m\(method)"
    }

    func monthData(year: Int, month: Int) throws -> PrayerTimesMonthData {
        guard let url = Self.cacheFileURL(sourceID: sourceID, year: year, month: month),
              let data = try? Data(contentsOf: url),
              let md = try? JSONDecoder().decode(PrayerTimesMonthData.self, from: data) else {
            throw PrayerTimesError.noPrayerTimesAvailable
        }
        return md
    }

    // MARK: - Shared cache location (writer = AladhanSync, reader = this provider)

    static func cacheFileURL(sourceID: String, year: Int, month: Int) -> URL? {
        guard let dir = AppGroup.cachesDirectory else { return nil }
        let safe = sourceID.replacingOccurrences(of: ":", with: "_")
        return dir.appendingPathComponent(String(format: "%@_%04d-%02d.json", safe, year, month))
    }

    // MARK: - Mapping Aladhan → PrayerTimesMonthData (used by AladhanSync)

    /// Convert an Aladhan month response into our model. Strips the " (TZ)" suffix from each
    /// timing, rebuilds the "yyyy-MM-dd'T'HH:mm:ss" strings the model parses, carries the city's
    /// timezone so instants are correct, and synthesizes hijri + place fields. azanSettings is a
    /// placeholder (Aladhan has no iqama data) — the service overrides it from settings.
    static func map(_ resp: AladhanMonthResponse, location: ResolvedLocation) -> PrayerTimesMonthData {
        let tz = location.timeZoneID ?? resp.data.first?.meta.timezone
        let cityEn = location.city ?? "—"
        let countryEn = location.countryName ?? location.countryISO ?? "—"

        let days: [DailyPrayerTimes] = resp.data.compactMap { day in
            guard let iso = gregorianISO(day.date.gregorian.date) else { return nil }
            func ts(_ s: String) -> String { iso + "T" + stripTZ(s) + ":00" }
            var d = DailyPrayerTimes(
                pid: abs(iso.hashValue),
                gDate: iso + "T00:00:00",
                dayofWeek: day.date.gregorian.weekday.en,
                hijryDay: Int(day.date.hijri.day) ?? 0,
                hijryMonth: day.date.hijri.month.number,
                hijryYear: Int(day.date.hijri.year) ?? 0,
                emsak: ts(day.timings.imsak),
                fajr: ts(day.timings.fajr),
                shurooq: ts(day.timings.sunrise),
                zuhr: ts(day.timings.dhuhr),
                asr: ts(day.timings.asr),
                maghrib: ts(day.timings.maghrib),
                isha: ts(day.timings.isha),
                comments: "Aladhan",
                areaNameAr: cityEn,
                areaNameEn: cityEn,
                emirateNameAr: countryEn,
                emirateNameEn: countryEn,
                areaID: -1,
                emirateID: -1,
                hijryMonthNameEn: day.date.hijri.month.en,
                hijryMonthNameAr: day.date.hijri.month.ar ?? day.date.hijri.month.en,
                gMonthNameEn: day.date.gregorian.month.en,
                gMonthNameAr: day.date.gregorian.month.ar ?? day.date.gregorian.month.en)
            d.sourceTimeZoneID = tz
            return d
        }
        return PrayerTimesMonthData(downloadLink: "", azanSettings: .uaeDefault, prayerData: days)
    }

    /// "DD-MM-YYYY" → "YYYY-MM-DD".
    private static func gregorianISO(_ s: String) -> String? {
        let p = s.split(separator: "-")
        guard p.count == 3 else { return nil }
        return "\(p[2])-\(p[1])-\(p[0])"
    }

    /// "02:31 (BST)" / "05:42 (+04)" → "02:31".
    private static func stripTZ(_ s: String) -> String {
        String(s.split(separator: " ").first ?? Substring(s))
    }
}
