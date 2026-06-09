//
//  ContentView.swift
//  Dubai iqama
//

import SwiftUI

struct ContentView: View {
    @StateObject private var countdownManager = CountdownManager.shared
    @Environment(\.openSettings) private var openSettings
    @State private var mock: MockScenario? = nil

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let now = mock?.time ?? ctx.date
            let day = countdownManager.currentState?.todayPrayerTimes
            let sunrise = day?.prayerTime(for: .fajr).map { $0.addingTimeInterval(80 * 60) }
            let sunset = day?.prayerTime(for: .maghrib)
            let body = SkyGeometry.bodyNormalized(at: now, sunrise: sunrise, sunset: sunset)

            ZStack {
                // 1. Window-level wallpaper blur (the macOS Tahoe glass).
                WindowBackdrop(material: .hudWindow)
                    .ignoresSafeArea()

                // 2. Celestial gradient tints the blurred wallpaper with the
                //    time-of-day mood without fully blocking it.
                CelestialBackground(
                    timeOverride: mock?.time,
                    bodyNormalizedX: body.x,
                    bodyIsDay: body.isDay
                )
                .opacity(0.55)
                .backgroundExtensionEffect()
                .ignoresSafeArea()

                // 3. AppKit interop: make the host NSWindow transparent.
                WindowTransparencyConfigurator()
                    .frame(width: 0, height: 0)

                VStack(spacing: 18) {
                    header
                        .padding(.top, 4)

                    SkyArcView(date: now,
                               todayPrayerTimes: day,
                               activePrayer: effectivePrayer)
                        .frame(height: 110)

                    countdownCard

                    prayerRail

                    MockScenarioStrip(selected: $mock)

                    Spacer(minLength: 0)

                    footer
                }
                .padding(.horizontal, 32)
                .padding(.top, 36)        // clear the traffic-light region
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 480, minHeight: 760)
        .preferredColorScheme(.dark)
        .onAppear { countdownManager.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dubai Iqama")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(dateString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            CrescentBadge()
        }
    }

    private var dateString: String {
        let df = DateFormatter()
        df.dateFormat = "EEEE, d MMMM"
        var s = df.string(from: Date())
        if let h = countdownManager.currentState?.todayPrayerTimes?.hijriDateString {
            s += " · " + h
        }
        return s
    }

    // MARK: - Countdown card

    private var countdownCard: some View {
        Group {
            if mock != nil {
                countdownBody(
                    prayer: effectivePrayer ?? .fajr,
                    isIqama: effectiveIsIqama,
                    countdownText: effectiveCountdownText,
                    day: countdownManager.currentState?.todayPrayerTimes,
                    settings: countdownManager.currentState?.azanSettings
                )
            } else if let snapshot = countdownManager.currentState {
                countdownBody(
                    prayer: snapshot.phase.prayer,
                    isIqama: snapshot.phase.isIqamaPhase,
                    countdownText: snapshot.formattedTimeRemaining,
                    day: snapshot.todayPrayerTimes,
                    settings: snapshot.azanSettings
                )
            } else if countdownManager.error != nil {
                errorBody
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .padding(18)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var effectivePrayer: Prayer? { mock?.prayer ?? countdownManager.currentState?.phase.prayer }
    private var effectiveIsIqama: Bool { mock?.isIqamaPhase ?? (countdownManager.currentState?.phase.isIqamaPhase ?? false) }
    private var effectiveCountdownText: String { mock?.formattedRemaining ?? (countdownManager.currentState?.formattedTimeRemaining ?? "—") }

    @ViewBuilder
    private func countdownBody(prayer: Prayer, isIqama: Bool, countdownText: String,
                                day: DailyPrayerTimes?, settings: AzanSettings?) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                PulsingDot(color: isIqama ? Theme.accentGold : Theme.accentEmerald)
                Text(isIqama ? "Iqama time" : "Next prayer")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.textSecondary)
                    .textCase(.uppercase)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(prayer.displayName)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(prayer.arabicName)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: 0.4), value: prayer.rawValue)

            Text(countdownText)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .shadow(color: (isIqama ? Theme.accentGold : Theme.accentEmerald).opacity(0.55),
                        radius: 14, x: 0, y: 0)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.35), value: countdownText)

            if let day, let azan = day.prayerTime(for: prayer) {
                HStack(spacing: 12) {
                    Label {
                        Text(azan, style: .time)
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "sun.haze")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)

                    if !isIqama, let settings {
                        let iqamaMin = settings.iqamaMinutes(for: prayer, isFriday: day.isFriday)
                        Text("·")
                            .foregroundStyle(Theme.textMuted)
                        Label("Iqama +\(iqamaMin)m", systemImage: "person.3.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    private var errorBody: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.accentGold)
            Text("Unable to load prayer times")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Button("Retry") { countdownManager.refresh() }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentEmerald)
        }
    }

    // MARK: - Prayer rail

    private var prayerRail: some View {
        VStack(spacing: 0) {
            ForEach(Prayer.orderedPrayers, id: \.self) { prayer in
                prayerRow(prayer: prayer)
                if prayer != .isha {
                    Rectangle()
                        .fill(Theme.cardStroke)
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 20, style: .continuous))
        .glassEffect(.clear.interactive(), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    @ViewBuilder
    private func prayerRow(prayer: Prayer) -> some View {
        let isCurrent = effectivePrayer == prayer
        let times = countdownManager.currentState?.todayPrayerTimes
        let settings = countdownManager.currentState?.azanSettings
        let isIqamaPhase = effectiveIsIqama

        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Theme.cardStroke, lineWidth: 1)
                    .frame(width: 22, height: 22)
                if isCurrent {
                    Circle()
                        .fill(isIqamaPhase ? Theme.accentGold : Theme.accentEmerald)
                        .frame(width: 10, height: 10)
                        .shadow(color: (isIqamaPhase ? Theme.accentGold : Theme.accentEmerald).opacity(0.7),
                                radius: 8, x: 0, y: 0)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(prayer.displayName)
                    .font(.system(size: 14, weight: isCurrent ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(prayer.arabicName)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }

            Spacer()

            if let times, let settings, let azan = times.prayerTime(for: prayer) {
                VStack(alignment: .trailing, spacing: 1) {
                    Text(azan, style: .time)
                        .font(.system(size: 14, weight: isCurrent ? .semibold : .regular, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isCurrent ? (isIqamaPhase ? Theme.accentGold : Theme.accentEmerald) : Theme.textPrimary)
                    let iqamaMin = settings.iqamaMinutes(for: prayer, isFriday: times.isFriday)
                    Text("+\(iqamaMin)m")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isCurrent ? Color.white.opacity(0.06) : .clear)
        .animation(.easeInOut(duration: 0.3), value: isCurrent)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(locationText)
                .font(.caption)
                .foregroundStyle(Theme.textMuted)

            Spacer()

            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var locationText: String {
        if let t = countdownManager.currentState?.todayPrayerTimes {
            return "\(t.areaNameEn) · \(t.emirateNameEn)"
        }
        return "Dubai · United Arab Emirates"
    }
}

// MARK: - Small accent components

private struct CrescentBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.cardFill)
                .overlay(Circle().stroke(Theme.cardStroke, lineWidth: 1))
                .frame(width: 38, height: 38)
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 16))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.glowSoft, Theme.accentGold],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .symbolEffect(.pulse, options: .repeating)
        }
    }
}

// Horizontal strip of preset scenarios + a "Live" reset chip. Lets you
// scrub through every visual state of the app without waiting for real time.
struct MockScenarioStrip: View {
    @Binding var selected: MockScenario?
    @Namespace private var chipNamespace

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 10))
                Text("Preview states")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Theme.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                // Sharing one GlassEffectContainer lets the chips visibly
                // morph/merge as you click between them — the signature
                // Liquid Glass interaction.
                GlassEffectContainer(spacing: 6) {
                    HStack(spacing: 6) {
                        chip(label: "Live", id: "live",
                             active: selected == nil) { selected = nil }
                        ForEach(MockScenario.presets) { scenario in
                            chip(label: scenario.label,
                                 id: scenario.label,
                                 active: selected?.id == scenario.id) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                    selected = scenario
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chip(label: String, id: String, active: Bool, tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Text(label)
                .font(.system(size: 11, weight: active ? .semibold : .medium, design: .rounded))
                .foregroundStyle(active ? Color.black : Theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glass(active
                            ? Glass.regular.tint(Theme.accentGold).interactive()
                            : Glass.clear.interactive()))
        .glassEffectID(id, in: chipNamespace)
    }
}

private struct PulsingDot: View {
    var color: Color
    @State private var on = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .shadow(color: color.opacity(0.8), radius: on ? 6 : 2)
            .opacity(on ? 1.0 : 0.65)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    on.toggle()
                }
            }
    }
}

#Preview {
    ContentView()
}
