//
//  Dubai_iqamaApp.swift
//  Dubai iqama
//
//  Created by Omar Altamimi on 21/01/2026.
//

import SwiftUI
import WidgetKit

@main
struct Dubai_iqamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize status bar
        statusBarController = StatusBarController()

        // Request notification permission
        NotificationManager.shared.requestPermission()

        // Preload current month data
        let currentMonth = Calendar.current.component(.month, from: Date())
        PrayerTimesService.shared.preloadMonth(currentMonth)

        // Force the widget extension to refresh timelines with the latest
        // design / data. Without this, widgets keep showing stale entries
        // from before the app was last updated.
        WidgetCenter.shared.reloadAllTimelines()

        // Check GitHub for a newer release now and once per day.
        UpdateChecker.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}

struct SettingsView: View {
    @AppStorage(AppSettings.Keys.notificationsEnabled)
    private var notificationsEnabled: Bool = AppSettings.Defaults.notificationsEnabled
    @AppStorage(AppSettings.Keys.notificationLeadMinutes)
    private var leadMinutes: Int = AppSettings.Defaults.notificationLeadMinutes

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dubai Iqama")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Preferences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $notificationsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Iqama reminders")
                            .font(.body)
                        Text("Notify me before the next iqama.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remind me")
                            .font(.body)
                        Text("Lead time before iqama.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Picker("", selection: $leadMinutes) {
                        ForEach(AppSettings.leadMinuteChoices, id: \.self) { m in
                            Text("\(m) minutes before").tag(m)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                    .disabled(!notificationsEnabled)
                }
            }

            Spacer()

            Text("Prayer times are bundled from Awqaf, Dubai Department of Islamic Affairs.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 460, height: 280)
    }
}
