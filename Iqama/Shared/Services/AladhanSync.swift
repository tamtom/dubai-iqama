import Foundation
import WidgetKit

/// Main-app-only coordinator that fetches Aladhan data for the active non-UAE location and writes
/// it to the shared App Group cache, then refreshes the countdown + widget. The widget itself never
/// fetches — it only reads what this writes. No-op when the resolved location is inside the UAE.
@MainActor
final class AladhanSync {
    static let shared = AladhanSync()
    private init() {}

    private var inFlight = false

    /// Kick a background sync for the current location if it's outside the UAE.
    func syncIfNeeded() {
        let loc = ResolvedLocation.current()
        guard !loc.isUAE else { return }
        Task { await sync(location: loc) }
    }

    func sync(location loc: ResolvedLocation) async {
        guard !loc.isUAE, !inFlight else { return }
        inFlight = true
        defer { inFlight = false }

        let method = CalculationMethod.resolved(setting: AppSettings.calcMethod, countryISO: loc.countryISO)
        let provider = AladhanProvider(location: loc, method: method)
        let cal = Calendar.current
        let now = Date()

        var wrote = false
        for (y, m) in monthsToFetch(now: now, calendar: cal) {
            guard let resp = await fetchMonth(year: y, month: m, location: loc, method: method) else { continue }
            let md = AladhanProvider.map(resp, location: loc)
            guard let url = AladhanProvider.cacheFileURL(sourceID: provider.sourceID, year: y, month: m),
                  let data = try? JSONEncoder().encode(md) else { continue }
            try? data.write(to: url, options: .atomic)
            wrote = true
        }

        if wrote {
            PrayerTimesService.shared.refreshProvider()
            CountdownManager.shared.refresh()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // Current month + next month, so a month rollover still has data.
    private func monthsToFetch(now: Date, calendar cal: Calendar) -> [(Int, Int)] {
        var result = [(cal.component(.year, from: now), cal.component(.month, from: now))]
        if let next = cal.date(byAdding: .month, value: 1, to: now) {
            result.append((cal.component(.year, from: next), cal.component(.month, from: next)))
        }
        return result
    }

    private func fetchMonth(year: Int, month: Int, location loc: ResolvedLocation, method: Int) async -> AladhanMonthResponse? {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "api.aladhan.com"
        // Prefer coordinates (robust); fall back to city/country.
        if let lat = loc.latitude, let lon = loc.longitude {
            comps.path = "/v1/calendar/\(year)/\(month)"
            comps.queryItems = [
                URLQueryItem(name: "latitude", value: String(lat)),
                URLQueryItem(name: "longitude", value: String(lon)),
                URLQueryItem(name: "method", value: String(method)),
            ]
        } else if let city = loc.city, let country = loc.countryName ?? loc.countryISO {
            comps.path = "/v1/calendarByCity/\(year)/\(month)"
            comps.queryItems = [
                URLQueryItem(name: "city", value: city),
                URLQueryItem(name: "country", value: country),
                URLQueryItem(name: "method", value: String(method)),
            ]
        } else {
            return nil
        }
        guard let url = comps.url else { return nil }
        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(AladhanMonthResponse.self, from: data)
        } catch {
            return nil
        }
    }
}
