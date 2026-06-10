//
//  widget.swift
//  widget
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct PrayerTimelineEntry: TimelineEntry {
    let date: Date
    let prayer: Prayer
    let targetTime: Date              // azan or iqama, whichever comes next
    let azanTime: Date
    let iqamaTime: Date
    let iqamaLeadMinutes: Int
    let isIqamaPhase: Bool
    let hijriDate: String
    let day: DailyPrayerTimes?        // for SkyArcView tick positions
    let bodyNormalizedX: Double       // sun/moon x position [0,1]
    let bodyIsDay: Bool

    static var placeholder: PrayerTimelineEntry {
        let now = Date()
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let target = cal.date(byAdding: .minute, value: 38, to: now) ?? now
        return PrayerTimelineEntry(
            date: now, prayer: .zuhr,
            targetTime: target,
            azanTime: target,
            iqamaTime: cal.date(byAdding: .minute, value: 20, to: target) ?? target,
            iqamaLeadMinutes: 20,
            isIqamaPhase: false,
            hijriDate: "23 ZelHaj 1447",
            day: nil,
            bodyNormalizedX: 0.5,
            bodyIsDay: true
        )
        _ = start
    }
}

// MARK: - Timeline Provider

struct PrayerTimelineProvider: TimelineProvider {
    typealias Entry = PrayerTimelineEntry

    func placeholder(in context: Context) -> PrayerTimelineEntry { .placeholder }
    func getSnapshot(in context: Context, completion: @escaping (PrayerTimelineEntry) -> Void) {
        completion(createEntry(for: Date()) ?? .placeholder)
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimelineEntry>) -> Void) {
        var entries: [PrayerTimelineEntry] = []
        var cursor = Date()
        for _ in 0..<20 {
            guard let entry = createEntry(for: cursor) else { break }
            entries.append(entry)
            let next = entry.targetTime.addingTimeInterval(1)
            if next > cursor { cursor = next } else { break }
        }
        if entries.isEmpty { entries.append(.placeholder) }
        let reload = entries.first?.targetTime ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: entries, policy: .after(reload)))
    }

    private func createEntry(for date: Date) -> PrayerTimelineEntry? {
        do {
            let service = PrayerTimesService.shared
            guard let info = try service.getNextPrayerInfo(from: date) else { return nil }
            let (prayer, azan, iqama, day) = info
            let isIqama = date >= azan && date < iqama
            let target = isIqama ? iqama : azan
            let settings = try service.getAzanSettings(for: day.gregorianDate ?? date)
            let leadMin = settings.iqamaMinutes(for: prayer, isFriday: day.isFriday)

            let sunrise = day.prayerTime(for: .fajr).map { $0.addingTimeInterval(80 * 60) }
            let sunset = day.prayerTime(for: .maghrib)
            let body = SkyGeometry.bodyNormalized(at: date, sunrise: sunrise, sunset: sunset)

            return PrayerTimelineEntry(
                date: date, prayer: prayer,
                targetTime: target,
                azanTime: azan, iqamaTime: iqama,
                iqamaLeadMinutes: leadMin,
                isIqamaPhase: isIqama,
                hijriDate: day.hijriDateString,
                day: day,
                bodyNormalizedX: body.x,
                bodyIsDay: body.isDay
            )
        } catch {
            return nil
        }
    }
}

// MARK: - Widget Definition

struct PrayerWidget: Widget {
    let kind: String = "PrayerTimesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimelineProvider()) { entry in
            PrayerWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    // System widget glass shows the desktop blur; we tint
                    // it with the time-of-day gradient at reduced opacity.
                    CelestialBackground(
                        animateOverTime: false,
                        timeOverride: entry.date,
                        bodyNormalizedX: entry.bodyNormalizedX,
                        bodyIsDay: entry.bodyIsDay
                    )
                    .opacity(0.55)
                }
        }
        .configurationDisplayName("Iqama")
        .description("Countdown to the next prayer and iqama.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct PrayerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PrayerTimelineEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:  SmallWidgetView(entry: entry)
            case .systemMedium: MediumWidgetView(entry: entry)
            case .systemLarge:  LargeWidgetView(entry: entry)
            default:            SmallWidgetView(entry: entry)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Shared widget components

private struct PrayerHeading: View {
    let prayer: Prayer
    let isIqama: Bool
    var size: CGFloat = 18

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(prayer.displayName)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(prayer.arabicName)
                .font(.system(size: size * 0.78))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct Countdown: View {
    let target: Date
    let isIqama: Bool
    var size: CGFloat

    var body: some View {
        Text(target, style: .timer)
            .font(.system(size: size, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .shadow(color: (isIqama ? Theme.accentGold : Theme.accentEmerald).opacity(0.55),
                    radius: size * 0.25)
    }
}

private struct PhaseLabel: View {
    let isIqama: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isIqama ? Theme.accentGold : Theme.accentEmerald)
                .frame(width: 5, height: 5)
                .shadow(color: (isIqama ? Theme.accentGold : Theme.accentEmerald).opacity(0.7), radius: 3)
            Text(isIqama ? "Iqama time" : "Next prayer")
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .textCase(.uppercase)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct PrayerRow: View {
    let slot: PrayerSlot
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 6 : 9) {
            Circle()
                .fill(slot.isCurrent ? Theme.accentEmerald : Color.white.opacity(0.25))
                .frame(width: 5, height: 5)
                .shadow(color: slot.isCurrent ? Theme.accentEmerald.opacity(0.7) : .clear, radius: 3)
            Text(slot.prayer.displayName)
                .font(.system(size: compact ? 10 : 11,
                              weight: slot.isCurrent ? .semibold : .regular,
                              design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            if !compact {
                Text(slot.prayer.arabicName)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer(minLength: 4)
            Text(slot.azan, style: .time)
                .font(.system(size: compact ? 10 : 11,
                              weight: slot.isCurrent ? .semibold : .regular,
                              design: .rounded))
                .monospacedDigit()
                .foregroundStyle(slot.isCurrent ? Theme.accentEmerald : Theme.textSecondary)
        }
    }
}

struct PrayerSlot: Identifiable {
    let id: String
    let prayer: Prayer
    let azan: Date
    let isCurrent: Bool
    init(prayer: Prayer, azan: Date, isCurrent: Bool) {
        self.id = prayer.rawValue
        self.prayer = prayer
        self.azan = azan
        self.isCurrent = isCurrent
    }
}

// Build prayer slots from a day's prayer times.
private func slots(from day: DailyPrayerTimes?, current: Prayer) -> [PrayerSlot] {
    guard let day else { return [] }
    return Prayer.orderedPrayers.compactMap { p in
        guard let azan = day.prayerTime(for: p) else { return nil }
        return PrayerSlot(prayer: p, azan: azan, isCurrent: p == current)
    }
}

// MARK: - Small

struct SmallWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SkyArcView(date: entry.date,
                       todayPrayerTimes: entry.day,
                       activePrayer: entry.prayer,
                       bodySize: 14)
                .frame(height: 38)

            PhaseLabel(isIqama: entry.isIqamaPhase)

            PrayerHeading(prayer: entry.prayer, isIqama: entry.isIqamaPhase, size: 15)

            Countdown(target: entry.targetTime, isIqama: entry.isIqamaPhase, size: 26)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Medium

struct MediumWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        VStack(spacing: 6) {
            SkyArcView(date: entry.date,
                       todayPrayerTimes: entry.day,
                       activePrayer: entry.prayer,
                       bodySize: 16)
                .frame(height: 44)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    PhaseLabel(isIqama: entry.isIqamaPhase)
                    PrayerHeading(prayer: entry.prayer, isIqama: entry.isIqamaPhase, size: 16)
                    Countdown(target: entry.targetTime, isIqama: entry.isIqamaPhase, size: 30)
                    Spacer(minLength: 0)
                }

                Rectangle().fill(Theme.cardStroke).frame(width: 1)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(slots(from: entry.day, current: entry.prayer)) { slot in
                        PrayerRow(slot: slot, compact: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Large

struct LargeWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Iqama")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    Text(entry.hijriDate)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.accentGold)
            }

            SkyArcView(date: entry.date,
                       todayPrayerTimes: entry.day,
                       activePrayer: entry.prayer,
                       bodySize: 22)
                .frame(height: 80)

            VStack(spacing: 4) {
                PhaseLabel(isIqama: entry.isIqamaPhase)
                PrayerHeading(prayer: entry.prayer, isIqama: entry.isIqamaPhase, size: 22)
                Countdown(target: entry.targetTime, isIqama: entry.isIqamaPhase, size: 42)
                HStack(spacing: 10) {
                    Label { Text(entry.azanTime, style: .time).monospacedDigit() }
                          icon: { Image(systemName: "sun.haze") }
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                    Text("·").foregroundStyle(Theme.textMuted)
                    Label("Iqama +\(entry.iqamaLeadMinutes)m", systemImage: "person.3.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle().fill(Theme.cardStroke).frame(height: 1)

            VStack(spacing: 5) {
                ForEach(slots(from: entry.day, current: entry.prayer)) { slot in
                    PrayerRow(slot: slot)
                }
            }
        }
    }
}

#Preview(as: .systemSmall) {
    PrayerWidget()
} timeline: {
    PrayerTimelineEntry.placeholder
}

#Preview(as: .systemMedium) {
    PrayerWidget()
} timeline: {
    PrayerTimelineEntry.placeholder
}

#Preview(as: .systemLarge) {
    PrayerWidget()
} timeline: {
    PrayerTimelineEntry.placeholder
}
