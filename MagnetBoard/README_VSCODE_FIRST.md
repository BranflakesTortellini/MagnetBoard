# Magnet Board — VS Code / pre-iPhone testing notes

This folder contains the Swift source files for the current Magnet Board prototype. It is not a full Xcode project by itself; it is a source bundle/checkpoint meant to be copied into a SwiftUI iOS app target.

## Current source files

- `MagnetBoardApp.swift` — app entry point
- `ContentView.swift` — top-level tabs and sheets
- `Models.swift` — app data models and planning enums
- `BoardViewModel.swift` — loose/free-board card persistence and actions
- `ScheduleViewModel.swift` — planned items, travel, calendar export, smart ordering
- `BoardViews.swift` — free magnet board UI
- `CardViews.swift` — sticky-note / magnet card UI
- `ScheduleViews.swift` — plan/day UI
- `MapViews.swift` — MapKit preview bridge
- `AddEditViews.swift` — new-card and edit-card flows
- `LocationSearchViewModel.swift` / `LocationSearchSheet.swift` — MapKit location search
- `PlanningSettingsView.swift` — home base, search area, day-shape settings
- `WelcomeHelpView.swift` — first-run help
- `VisualDesign.swift` — cute colors, badges, card styling helpers
- `DelightUndoViewModel.swift` — undo banner and playful clear effects
- `Helpers.swift` — small utilities

## Xcode project settings needed later

When this is put into a real iOS target, the project should include Calendar usage strings in `Info.plist` if Apple Calendar export remains enabled:

- `NSCalendarsWriteOnlyAccessUsageDescription`
- possibly legacy `NSCalendarsUsageDescription` if supporting older iOS versions

Suggested text:

> Magnet Board uses Calendar access only when you choose to export an in-app plan to Apple Calendar.

The app currently uses MapKit search and routing. Map search/routing does not require foreground location permission when the user searches manually; only add location permission keys if a future version uses the user's current GPS location.

## VS Code workflow

VS Code is fine for editing and Git. For actual iPhone deployment, the code still needs an iOS app target built by Xcode or another Apple toolchain wrapper.

Recommended workflow:

1. Keep this folder in Git.
2. Edit in VS Code.
3. Use small commits by feature/pass.
4. Later, open/create the iOS target in Xcode and add these Swift files.
5. Build on Simulator first, then device.

## Current honest limitation

This checkpoint has not been compiled against SwiftUI/MapKit/EventKit in this environment. Treat it as a strong source checkpoint, not a verified App Store-ready build.
