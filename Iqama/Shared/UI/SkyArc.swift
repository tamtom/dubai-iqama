import SwiftUI

// Shared geometry — used by both the arc view and the background halo so
// the warm halo in the gradient anchors to wherever the sun/moon currently is.
enum SkyGeometry {
    // Returns the celestial body's normalized x position [0,1] and whether
    // it's currently above the horizon (day) or below (night).
    static func bodyNormalized(at date: Date,
                                sunrise: Date?,
                                sunset: Date?) -> (x: Double, dayPhase: Double, isDay: Bool) {
        // dayPhase ∈ [0,1] along the visible arc (rises at sunrise → sets at sunset
        // during day; rises at sunset → sets at next sunrise during night).
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let sr = sunrise ?? cal.date(byAdding: .hour, value: 6, to: startOfDay)!
        let ss = sunset ?? cal.date(byAdding: .hour, value: 18, to: startOfDay)!

        let nowS = date.timeIntervalSinceReferenceDate
        let srS = sr.timeIntervalSinceReferenceDate
        let ssS = ss.timeIntervalSinceReferenceDate

        if nowS >= srS && nowS <= ssS {
            // Daytime
            let t = (nowS - srS) / max(60, ssS - srS)
            return (x: t, dayPhase: t, isDay: true)
        }

        // Nighttime — mirror across midnight using same sunrise/sunset for next day.
        let nextSunrise = cal.date(byAdding: .day, value: 1, to: sr)!.timeIntervalSinceReferenceDate
        let prevSunset = cal.date(byAdding: .day, value: -1, to: ss)!.timeIntervalSinceReferenceDate
        let (startS, endS): (Double, Double) = nowS < srS ? (prevSunset, srS) : (ssS, nextSunrise)
        let t = (nowS - startS) / max(60, endS - startS)
        return (x: t, dayPhase: t, isDay: false)
    }
}

// A thin band placed near the top of the window: arc trajectory, prayer tick
// marks at their real local times, and a glowing sun (day) or moon (night)
// gliding along the arc at the current position.
struct SkyArcView: View {
    var date: Date
    var todayPrayerTimes: DailyPrayerTimes?
    var activePrayer: Prayer?
    var bodySize: CGFloat = 36

    var body: some View {
        GeometryReader { geo in
            content(in: geo.size)
        }
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        let sunrise = todayPrayerTimes?.prayerTime(for: .fajr).map { addSunriseOffset(from: $0) } ?? defaultSunrise(date)
        let sunset = todayPrayerTimes?.prayerTime(for: .maghrib) ?? defaultSunset(date)

        let inset: CGFloat = 30
        let arcLeft = inset
        let arcRight = size.width - inset
        let baseY = size.height - 14
        let peakY = 18.0

        let body = SkyGeometry.bodyNormalized(at: date, sunrise: sunrise, sunset: sunset)
        let bodyPos = arcPoint(t: body.x, left: arcLeft, right: arcRight, base: baseY, peak: peakY)

        ZStack {
            // 1. Dashed arc trajectory
            Path { p in
                let steps = 60
                for i in 0...steps {
                    let t = Double(i) / Double(steps)
                    let pt = arcPoint(t: t, left: arcLeft, right: arcRight, base: baseY, peak: peakY)
                    if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                }
            }
            .stroke(Color.white.opacity(0.16),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round, dash: [2, 4]))

            // 2. Horizon line
            Path { p in
                p.move(to: CGPoint(x: arcLeft, y: baseY))
                p.addLine(to: CGPoint(x: arcRight, y: baseY))
            }
            .stroke(Color.white.opacity(0.20), lineWidth: 0.6)

            // 3. Prayer ticks
            ForEach(Prayer.orderedPrayers, id: \.self) { prayer in
                if let azan = todayPrayerTimes?.prayerTime(for: prayer) {
                    let t = normalize(time: azan, sunrise: sunrise, sunset: sunset)
                    let pt = arcPoint(t: t, left: arcLeft, right: arcRight, base: baseY, peak: peakY)
                    let isActive = activePrayer == prayer
                    Circle()
                        .fill(isActive ? Theme.accentGold : Color.white.opacity(0.55))
                        .frame(width: isActive ? 7 : 4, height: isActive ? 7 : 4)
                        .shadow(color: isActive ? Theme.accentGold.opacity(0.7) : .clear, radius: 6)
                        .position(pt)
                    Text(prayer.displayName.prefix(1))
                        .font(.system(size: 9, weight: isActive ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isActive ? Theme.accentGold : Theme.textMuted)
                        .position(x: pt.x, y: baseY + 10)
                }
            }

            // 4. Sun / moon glyph at current position
            CelestialBodyGlyph(isDay: body.isDay)
                .frame(width: bodySize, height: bodySize)
                .position(bodyPos)
        }
    }

    private func arcPoint(t: Double, left: CGFloat, right: CGFloat, base: CGFloat, peak: CGFloat) -> CGPoint {
        let clampedT = min(max(t, 0), 1)
        let x = left + CGFloat(clampedT) * (right - left)
        let y = base - sin(clampedT * .pi) * (base - peak)
        return CGPoint(x: x, y: y)
    }

    private func normalize(time: Date, sunrise: Date, sunset: Date) -> Double {
        let span = sunset.timeIntervalSince(sunrise)
        guard span > 0 else { return 0.5 }
        return min(max(time.timeIntervalSince(sunrise) / span, 0), 1)
    }

    // Awqaf "fajr" is dawn / first light; actual sunrise is ~80 min later.
    // For arc geometry we want astronomical sunrise. Approximate using
    // shurooq if available via the data fields — fall back to fajr + 80m.
    private func addSunriseOffset(from fajr: Date) -> Date {
        fajr.addingTimeInterval(80 * 60)
    }

    private func defaultSunrise(_ d: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 6, minute: 0, second: 0, of: d) ?? d
    }
    private func defaultSunset(_ d: Date) -> Date {
        let cal = Calendar.current
        return cal.date(bySettingHour: 18, minute: 30, second: 0, of: d) ?? d
    }
}

private struct CelestialBodyGlyph: View {
    let isDay: Bool

    var body: some View {
        ZStack {
            if isDay {
                // Sun: warm gradient disc with diffuse glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 1.0, green: 0.92, blue: 0.65),
                                     Color(red: 1.0, green: 0.78, blue: 0.30)],
                            center: .center, startRadius: 1, endRadius: 18
                        )
                    )
                    .shadow(color: Theme.accentGold.opacity(0.55), radius: 14)
                    .shadow(color: Theme.accentGold.opacity(0.35), radius: 28)
            } else {
                // Moon: cool pale disc with subtle crater accent + soft glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.97, green: 0.96, blue: 0.92),
                                     Color(red: 0.82, green: 0.83, blue: 0.92)],
                            center: .init(x: 0.4, y: 0.4), startRadius: 1, endRadius: 18
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.45), lineWidth: 0.6)
                    )
                    .shadow(color: Color.white.opacity(0.35), radius: 14)
            }
        }
    }
}
