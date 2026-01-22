//
//  ContentView.swift
//  Uae iqama
//
//  Created by Omar Altamimi on 21/01/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var countdownManager = CountdownManager.shared

    var body: some View {
        VStack(spacing: 24) {
            headerSection

            Divider()

            countdownSection

            Divider()

            prayerTimesSection

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 500)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)

                Text("Dubai Iqama")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }

            HStack(spacing: 16) {
                Text(Date(), style: .date)
                    .font(.headline)

                if let times = countdownManager.currentState?.todayPrayerTimes {
                    Text("|")
                        .foregroundColor(.secondary)

                    Text(times.hijriDateString)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            if let times = countdownManager.currentState?.todayPrayerTimes {
                Text("\(times.areaNameEn), \(times.emirateNameEn)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        VStack(spacing: 12) {
            if let snapshot = countdownManager.currentState {
                Text(snapshot.phase.isIqamaPhase ? "Time until Iqama" : "Time until \(snapshot.phase.prayer.displayName)")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text(snapshot.formattedTimeRemaining)
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(countdownColor(for: snapshot))
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: snapshot.formattedTimeRemaining)

                HStack(spacing: 8) {
                    Circle()
                        .fill(snapshot.phase.isIqamaPhase ? Color.orange : Color.accentColor)
                        .frame(width: 12, height: 12)
                        .animation(.easeInOut, value: snapshot.phase.isIqamaPhase)

                    Text(snapshot.phase.displayLabel)
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .animation(.easeInOut, value: snapshot.phase.displayLabel)
            } else if countdownManager.error != nil {
                errorView
            } else {
                ProgressView("Loading prayer times...")
            }
        }
        .padding(.vertical, 16)
    }

    private var errorView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Unable to load prayer times")
                .font(.headline)

            Text("Please ensure the prayer times data files are available.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                countdownManager.refresh()
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Prayer Times List

    private var prayerTimesSection: some View {
        VStack(spacing: 12) {
            Text("Today's Prayer Times")
                .font(.headline)

            if let times = countdownManager.currentState?.todayPrayerTimes,
               let settings = countdownManager.currentState?.azanSettings {
                VStack(spacing: 0) {
                    ForEach(Prayer.orderedPrayers, id: \.self) { prayer in
                        prayerRow(prayer: prayer, times: times, settings: settings)

                        if prayer != .isha {
                            Divider()
                        }
                    }
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
    }

    private func prayerRow(prayer: Prayer, times: DailyPrayerTimes, settings: AzanSettings) -> some View {
        let isCurrent = countdownManager.currentState?.phase.prayer == prayer

        return HStack {
            HStack(spacing: 12) {
                Circle()
                    .fill(isCurrent ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(prayer.displayName)
                        .font(.body)
                        .fontWeight(isCurrent ? .bold : .regular)

                    Text(prayer.arabicName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let azanTime = times.prayerTime(for: prayer) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(azanTime, style: .time)
                        .font(.body)
                        .fontWeight(isCurrent ? .bold : .regular)
                        .foregroundColor(isCurrent ? .accentColor : .primary)

                    let iqamaMinutes = settings.iqamaMinutes(for: prayer, isFriday: times.isFriday)
                    Text("Iqama: +\(iqamaMinutes)m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isCurrent ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    private func countdownColor(for snapshot: CountdownSnapshot) -> Color {
        switch snapshot.phase {
        case .waitingForAzan:
            if snapshot.timeRemaining < 60 {
                return .red
            } else if snapshot.timeRemaining < 300 {
                return .orange
            }
            return .primary
        case .waitingForIqama:
            return .green
        }
    }
}

#Preview {
    ContentView()
}
