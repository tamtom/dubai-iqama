//
//  Dubai_iqamaApp.swift
//  Dubai iqama
//
//  Created by Omar Altamimi on 21/01/2026.
//

import SwiftUI

@main
struct Dubai_iqamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }

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
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup if needed
    }
}

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Dubai Iqama Settings")
                .font(.headline)

            Text("Prayer times are loaded from local data files.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}
