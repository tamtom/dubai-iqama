import Foundation

// Hand-crafted scenarios used by the in-app "preview states" strip.
// Each scenario pins a wall-clock time, an active prayer, a phase, and a
// remaining countdown so the entire UI (background gradient, countdown card,
// prayer rail) can be exercised without waiting for real time to pass.
struct MockScenario: Identifiable, Equatable {
    let id = UUID()
    let label: String
    let time: Date
    let prayer: Prayer
    let isIqamaPhase: Bool
    let remainingSeconds: Int

    static let presets: [MockScenario] = [
        .at(hour: 3, minute: 30, label: "Pre-dawn",   prayer: .fajr,    iqama: false, remaining: 1850),
        .at(hour: 4, minute: 1,  label: "Dawn",       prayer: .fajr,    iqama: false, remaining: 60),
        .at(hour: 4, minute: 8,  label: "Fajr iqama", prayer: .fajr,    iqama: true,  remaining: 1100),
        .at(hour: 7, minute: 30, label: "Sunrise",    prayer: .zuhr,    iqama: false, remaining: 17_300),
        .at(hour: 12, minute: 20, label: "Noon",      prayer: .zuhr,    iqama: false, remaining: 60),
        .at(hour: 12, minute: 30, label: "Zuhr iqama", prayer: .zuhr,   iqama: true,  remaining: 900),
        .at(hour: 15, minute: 41, label: "Afternoon", prayer: .asr,     iqama: false, remaining: 60),
        .at(hour: 18, minute: 50, label: "Pre-sunset", prayer: .maghrib, iqama: false, remaining: 1280),
        .at(hour: 19, minute: 11, label: "Sunset",    prayer: .maghrib, iqama: false, remaining: 30),
        .at(hour: 19, minute: 15, label: "Maghrib iqama", prayer: .maghrib, iqama: true, remaining: 240),
        .at(hour: 20, minute: 25, label: "Dusk",      prayer: .isha,    iqama: false, remaining: 720),
        .at(hour: 23, minute: 0,  label: "Deep night", prayer: .fajr,   iqama: false, remaining: 18_000),
    ]

    private static func at(hour: Int, minute: Int, label: String, prayer: Prayer, iqama: Bool, remaining: Int) -> MockScenario {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        let d = cal.date(from: comps) ?? Date()
        return MockScenario(label: label, time: d, prayer: prayer, isIqamaPhase: iqama, remainingSeconds: remaining)
    }

    var formattedRemaining: String {
        let s = max(0, remainingSeconds)
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }
}
