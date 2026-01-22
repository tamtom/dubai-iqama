//
//  widget.swift
//  widget
//
//  Created by Omar Altamimi on 21/01/2026.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct PrayerTimelineEntry: TimelineEntry {
    let date: Date
    let prayerName: String
    let arabicName: String
    let targetTime: Date
    let isIqamaPhase: Bool
    let hijriDate: String
    let allPrayerTimes: [(name: String, arabicName: String, time: Date, isCurrent: Bool)]

    static var placeholder: PrayerTimelineEntry {
        PrayerTimelineEntry(
            date: Date(),
            prayerName: "Fajr",
            arabicName: "الفجر",
            targetTime: Date().addingTimeInterval(3600),
            isIqamaPhase: false,
            hijriDate: "12 Rajab 1447",
            allPrayerTimes: []
        )
    }
}

// MARK: - Timeline Provider

struct PrayerTimelineProvider: TimelineProvider {
    typealias Entry = PrayerTimelineEntry

    func placeholder(in context: Context) -> PrayerTimelineEntry {
        PrayerTimelineEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerTimelineEntry) -> Void) {
        let entry = createEntry(for: Date()) ?? PrayerTimelineEntry.placeholder
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerTimelineEntry>) -> Void) {
        var entries: [PrayerTimelineEntry] = []
        let now = Date()

        // Generate entries for prayer transitions
        var currentDate = now

        for _ in 0..<20 {
            if let entry = createEntry(for: currentDate) {
                entries.append(entry)

                // Move to next transition time + 1 second
                let nextDate = entry.targetTime.addingTimeInterval(1)
                if nextDate > currentDate {
                    currentDate = nextDate
                } else {
                    break
                }
            } else {
                break
            }
        }

        // If no entries, add placeholder
        if entries.isEmpty {
            entries.append(PrayerTimelineEntry.placeholder)
        }

        // Reload at next target time or in 15 minutes
        let reloadDate = entries.first?.targetTime ?? now.addingTimeInterval(900)
        let timeline = Timeline(entries: entries, policy: .after(reloadDate))
        completion(timeline)
    }

    private func createEntry(for date: Date) -> PrayerTimelineEntry? {
        do {
            let service = PrayerTimesService.shared

            guard let nextPrayerInfo = try service.getNextPrayerInfo(from: date) else {
                return nil
            }

            let (prayer, azanTime, iqamaTime, dailyTimes) = nextPrayerInfo

            let isIqamaPhase = date >= azanTime && date < iqamaTime
            let targetTime = isIqamaPhase ? iqamaTime : azanTime

            // Build all prayer times list
            var allTimes: [(String, String, Date, Bool)] = []
            for p in Prayer.orderedPrayers {
                if let time = dailyTimes.prayerTime(for: p) {
                    allTimes.append((p.displayName, p.arabicName, time, p == prayer))
                }
            }

            return PrayerTimelineEntry(
                date: date,
                prayerName: prayer.displayName,
                arabicName: prayer.arabicName,
                targetTime: targetTime,
                isIqamaPhase: isIqamaPhase,
                hijriDate: dailyTimes.hijriDateString,
                allPrayerTimes: allTimes
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Prayer Times")
        .description("Shows countdown to next prayer and iqama.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Widget Views

struct PrayerWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: PrayerTimelineEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget

struct SmallWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "moon.stars.fill")
                    .font(.caption)
                    .symbolEffect(.pulse)
                Text(entry.prayerName)
                    .fontWeight(.semibold)
            }
            .font(.headline)

            Text(entry.targetTime, style: .timer)
                .font(.system(size: 32, weight: .bold, design: .monospaced))
                .minimumScaleFactor(0.5)
                .foregroundColor(entry.isIqamaPhase ? .green : .primary)
                .contentTransition(.numericText())

            Text(entry.isIqamaPhase ? "until Iqama" : "until Azan")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Medium Widget

struct MediumWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Countdown
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .symbolEffect(.pulse)
                    Text(entry.prayerName)
                }
                .font(.headline)

                Text(entry.targetTime, style: .timer)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundColor(entry.isIqamaPhase ? .green : .primary)
                    .contentTransition(.numericText())

                Text(entry.isIqamaPhase ? "Iqama" : "Azan")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(entry.hijriDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // Right: Prayer times list
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                ForEach(entry.allPrayerTimes.prefix(5), id: \.name) { item in
                    HStack {
                        Text(item.name)
                            .font(.caption2)
                            .fontWeight(item.isCurrent ? .bold : .regular)
                        Spacer()
                        Text(item.time, style: .time)
                            .font(.caption2)
                    }
                    .foregroundColor(item.isCurrent ? .accentColor : .primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
}

// MARK: - Large Widget

struct LargeWidgetView: View {
    let entry: PrayerTimelineEntry

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Prayer Times")
                        .font(.headline)
                    Text(entry.hijriDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse)
            }

            Divider()

            // Main countdown
            VStack(spacing: 8) {
                Text("Next: \(entry.prayerName) \(entry.isIqamaPhase ? "Iqama" : "")")
                    .font(.title3)
                    .fontWeight(.medium)

                Text(entry.targetTime, style: .timer)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(entry.isIqamaPhase ? .green : .primary)
                    .contentTransition(.numericText())
            }
            .padding(.vertical, 8)

            Divider()

            // All prayers
            VStack(spacing: 8) {
                ForEach(entry.allPrayerTimes, id: \.name) { item in
                    HStack {
                        Circle()
                            .fill(item.isCurrent ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)

                        Text(item.name)
                            .fontWeight(item.isCurrent ? .bold : .regular)

                        Text(item.arabicName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(item.time, style: .time)
                            .foregroundColor(item.isCurrent ? .accentColor : .primary)
                    }
                    .font(.subheadline)
                }
            }
        }
        .padding()
    }
}

// MARK: - Preview

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
