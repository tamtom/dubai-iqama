# Dubai Iqama

A native macOS prayer-times app for Dubai with a celestial-themed Liquid Glass UI, a menu-bar countdown, and matching home-screen widgets.

Prayer times come straight from the official **Awqaf, Dubai Department of Islamic Affairs** API and are bundled with the app — no network required at runtime.

<p align="center">
  <img src="docs/screenshots/main-window.png" width="640" alt="Dubai Iqama main window — Maghrib countdown with sky arc">
</p>

## Highlights

- **Celestial Hours** theme — the background gradient shifts smoothly through the day; a glowing sun (or moon at night) traces a real solar arc across the top of the window, with ticks for Fajr · Zuhr · Asr · Maghrib · Isha at their actual local times.
- **Liquid Glass everywhere** — countdown card, prayer rail, and chip strip use the macOS 26 Tahoe `.glassEffect` material with `.interactive()` specular highlights and a `GlassEffectContainer` for fluid morph animations. The window is non-opaque so the desktop wallpaper blurs through it.
- **Menu-bar status item** — at-a-glance "next prayer + countdown" right in the menu bar; click to drop a full popover.
- **Widget extension** — small / medium / large widgets that mirror the main app's design, including the live sky arc.
- **Configurable iqama notifications** — toggle reminders and pick the lead time (2, 5, 10, 15, 20, or 30 minutes before iqama) from a real Settings panel.
- **Notarized & stapled** — distributed DMG is signed with a Developer ID Application certificate and notarized by Apple, so it opens cleanly on any Mac without Gatekeeper warnings.

## Screenshots

### Main window

<p align="center">
  <img src="docs/screenshots/main-window.png" width="640" alt="Main window during Maghrib iqama">
</p>

The sky-arc band tracks the sun/moon across the day; the active prayer's tick glows. Below it, a glass countdown card and prayer rail with bilingual labels (English + Arabic) and per-prayer iqama offsets.

### Menu-bar popover

<p align="center">
  <img src="docs/screenshots/menu-bar.png" width="520" alt="Menu-bar popover">
</p>

Same theme scaled down — note the live countdown next to the moon icon in the system menu bar (`Asr 1h 13m`).

### Widget

<p align="center">
  <img src="docs/screenshots/widget-medium.png" width="520" alt="Medium widget on the desktop">
</p>

Medium widget on the desktop showing the sky arc, the next prayer name in Arabic + English, the countdown, and a quick rail of today's times.

## Install

1. Download the latest `Dubai-Iqama-1.0.dmg` from the [Releases page](https://github.com/tamtom/dubai-iqama/releases/latest).
2. Open the DMG and drag **Dubai Iqama** into your **Applications** folder.
3. Launch from Spotlight or Launchpad. The first launch will ask for notification permission (used only for iqama reminders).

Optional: open the **Widget Gallery** (right-click the desktop → Edit Widgets) to add one of the three widget sizes.

## Build from source

Requires **Xcode 26+** running on **macOS 26 Tahoe** (the app uses Liquid Glass APIs).

```bash
git clone https://github.com/tamtom/dubai-iqama.git
cd dubai-iqama
open "Dubai iqama.xcodeproj"
```

Build the `Dubai iqama` scheme. The first time you build, Xcode will sign with your personal team for local-only execution; the **Release** configuration is wired to sign with a Developer ID Application certificate for distribution.

## Release pipeline

`Scripts/release.sh` produces a fully notarized, stapled DMG ready to attach to a GitHub release:

1. `xcodebuild archive` (Release, Developer ID, hardened runtime)
2. `xcodebuild -exportArchive` with `developer-id` (strips Debug entitlements, adds secure timestamp)
3. Zip the `.app` → `xcrun notarytool submit --wait` → `xcrun stapler staple`
4. Build a DMG containing the stapled app → submit it for its own notarization → staple it too

One-time setup of the notarization credential (stored in your login keychain, **never** in the repo):

```bash
xcrun notarytool store-credentials "DubaiIqamaNotary" \
    --apple-id "your-apple-id@example.com" \
    --team-id "W5THJP5XXD" \
    --password "app-specific-password-from-appleid.apple.com"
```

Then:

```bash
./Scripts/release.sh
```

A `Dubai-Iqama-<version>.dmg` lands on your Desktop. `spctl --assess` reports `accepted` with `source=Notarized Developer ID`.

## Architecture

- **Main app target** — SwiftUI window + status bar `NSPopover` hosted from `AppDelegate`. `CountdownManager` ticks on a `Timer` and publishes `CountdownSnapshot`s; views observe via `@StateObject`.
- **Widget extension** — `WidgetKit` timeline provider builds entries at each prayer transition. Shares the prayer-times JSON via a symlink (`widget/prayer_times_2026` → `../Dubai iqama/prayer_times_2026`) and the theme/sky-arc views via symlinks to `Dubai iqama/Shared/UI/`.
- **Prayer data** — 12 monthly JSON files under `Dubai iqama/prayer_times_2026/`, one per Gregorian month, full year 2026 from the Awqaf Dubai endpoint. Each file carries the azan settings (iqama offsets) and a per-day record with Gregorian + Hijri dates and prayer times.
- **Theme** — `Shared/UI/Theme.swift` interpolates a 12-keyframe palette through the day; `CelestialBackground.swift` composes the gradient + 8-point-star ornament + drifting starlight; `SkyArc.swift` draws the half-ellipse + prayer ticks + sun/moon disc; `WindowBackdrop.swift` is an `NSViewRepresentable` that makes the window non-opaque so the desktop wallpaper blurs through.

## Data source & accuracy

Prayer times are the official ones published by [Awqaf, Dubai Department of Islamic Affairs](https://www.awqaf.gov.ae) for **Dubai (emirateID=2, areaID=32)**. The full 2026 dataset is bundled with the app; no API calls happen at runtime.

If you need to backfill a future year before Awqaf publishes it, the [Aladhan public API](https://aladhan.com/prayer-times-api) with `method=16` ("Dubai experimental") matches Awqaf within ±1 minute for Fajr / Zuhr / Maghrib / Isha across the year, with a systematic offset on Asr (~+2 min) and Shurooq (~−4 min) that can be calibrated.

## License

See [LICENSE](LICENSE) if present, otherwise all rights reserved.
