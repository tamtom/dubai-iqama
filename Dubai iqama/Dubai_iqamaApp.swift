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
        .windowResizability(.contentMinSize)
        .defaultSize(width: 480, height: 860)

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

        // Preload current month so the first paint isn't blank (uses the stored location,
        // defaulting to Dubai), then auto-detect to refine it.
        let currentMonth = Calendar.current.component(.month, from: Date())
        PrayerTimesService.shared.preloadMonth(currentMonth)

        // Resolve the user's location (auto mode) and, if outside the UAE, fetch + cache Aladhan
        // data. Both refresh the countdown + widgets when they complete.
        LocationManager.shared.resolveIfAuto()
        AladhanSync.shared.syncIfNeeded()

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
