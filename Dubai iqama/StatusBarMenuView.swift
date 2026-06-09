import SwiftUI

struct StatusBarMenuView: View {
    @StateObject private var countdownManager = CountdownManager.shared

    var body: some View {
        VStack(spacing: 16) {
            headerView

            Divider()

            countdownView

            Divider()

            todayPrayerTimesView

            Divider()

            footerView
        }
        .padding()
        .frame(width: 280)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            Text(Date(), style: .date)
                .font(.headline)

            if let times = countdownManager.currentState?.todayPrayerTimes {
                Text(times.hijriDateString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack(spacing: 8) {
            if let snapshot = countdownManager.currentState {
                Text(snapshot.phase.displayLabel)
                    .font(.title2)
                    .fontWeight(.medium)
                    .animation(.easeInOut, value: snapshot.phase.displayLabel)

                Text(snapshot.formattedTimeRemaining)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(countdownColor(for: snapshot))
                    .contentTransition(.numericText())
                    .animation(.spring(duration: 0.3), value: snapshot.formattedTimeRemaining)

                if snapshot.phase.isIqamaPhase {
                    Text("Iqama time")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .transition(.opacity)
                }
            } else if countdownManager.error != nil {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Unable to load prayer times")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                ProgressView()
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Prayer Times List

    private var todayPrayerTimesView: some View {
        VStack(spacing: 8) {
            Text("Today's Prayer Times")
                .font(.subheadline)
                .fontWeight(.medium)

            if let times = countdownManager.currentState?.todayPrayerTimes {
                ForEach(Prayer.orderedPrayers, id: \.self) { prayer in
                    prayerTimeRow(prayer: prayer, times: times)
                }
            }
        }
    }

    private func prayerTimeRow(prayer: Prayer, times: DailyPrayerTimes) -> some View {
        HStack {
            Circle()
                .fill(isCurrentPrayer(prayer) ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            Text(prayer.displayName)
                .fontWeight(isCurrentPrayer(prayer) ? .bold : .regular)

            Spacer()

            if let time = times.prayerTime(for: prayer) {
                Text(time, style: .time)
                    .foregroundColor(isCurrentPrayer(prayer) ? .accentColor : .primary)
            }
        }
        .font(.caption)
    }

    private func isCurrentPrayer(_ prayer: Prayer) -> Bool {
        countdownManager.currentState?.phase.prayer == prayer
    }

    private func countdownColor(for snapshot: CountdownSnapshot) -> Color {
        switch snapshot.phase {
        case .waitingForAzan:
            return snapshot.timeRemaining < 300 ? .orange : .primary
        case .waitingForIqama:
            return .green
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Open App") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .font(.caption)
        .foregroundColor(.secondary)
    }
}

#Preview {
    StatusBarMenuView()
        .frame(width: 300, height: 450)
}
