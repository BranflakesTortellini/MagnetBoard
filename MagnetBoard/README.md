# Magnet Board Planner

A visual sticky-note / magnet-board planner for iPhone and iPad.

This project is a SwiftUI prototype for a gift app: a playful, low-friction planning board where someone can dump loose ideas, move them around like sticky notes, gradually turn them into a rough day plan, and only make things exact/calendar-ready when they are actually ready.

The design goal is not to make another rigid calendar app. The goal is to make planning on a phone feel more like arranging cute little notes on a board.

## Current status

This bundle is the current pre-iPhone-test source checkpoint. It includes all Swift source files and project notes produced so far.

Important honesty note: this source has been code-inspected and organized, but it has **not** been compiled in Xcode inside this environment. SwiftUI, MapKit, and EventKit require a real Apple toolchain/project setup for final compile testing. Expect small Xcode/SDK cleanup issues on first build.

## Core product idea

The app supports this flow:

1. Add loose ideas as cute cards.
2. Move them around freely on a board.
3. Group them visually by vibe, priority, or rough plan.
4. Drop them into rough day buckets like morning, afternoon, evening, or sometime today.
5. Mark important items as “must happen” without forcing an exact time.
6. Promote only real commitments to exact times.
7. Export exact-time items to Apple Calendar when ready.
8. Use Maps or manual estimates for travel time.
9. Undo mistakes easily.

## Main modes

### Board mode

Board mode is the free sticky-note canvas.

Users can:

- create cards
- tap cards to edit
- hold cards to move them
- drag cards between board zones
- use a sample board
- tidy the board
- use cute category colors and emojis

Board zones currently include:

- Must do
- Ideas
- Maybe
- Needs info
- In the plan

### Plan mode

Plan mode turns cards into a day plan without forcing exact scheduling too early.

Users can drop cards into:

- Morning
- Afternoon
- Evening
- Sometime today
- Must happen today

Planned items can later be promoted to exact-time events.

## Major implemented features

- SwiftUI app shell with Board and Plan tabs
- Local JSON persistence for ideas and scheduled events
- Loose / detailed / scheduled / locked card commitment model
- Board positions and board groups
- Activity categories with emojis and soft pastel styling
- Repeatability control to avoid accidental duplicate scheduling
- Semi-structured planning: day-only, daypart, exact time
- “Must happen today/this morning/this afternoon/this evening” semantics
- MapKit travel estimate support when coordinates exist
- Manual travel estimate support when user does not want to use Maps
- Safe app-level travel mode enum, including a cycling fallback
- Location search with configurable search area
- Home base settings
- Optional home-to-first-stop and last-stop-to-home legs
- Day summary card
- Smart order for rough cards using category rules and lightweight distance hints
- Sequence rule toggles, persisted with AppStorage
- Calendar export only after user explicitly exports
- EventKit ID storage so re-export can update existing calendar events
- Undo banner for destructive actions
- Clear day / clear all scheduled items with undo
- Playful clear animation and haptics hooks
- Swipe-to-delete for planned rows
- Drag-to-reorder planned rows
- First-run help screen
- Quick-start templates
- Sample board
- Cute visual design pass with soft colors, emojis, board doodles, and paper-like shadows
- Reduce playful motion setting
- Basic accessibility labels/hints

## Files in this bundle

### App entry and root

- `MagnetBoardApp.swift` — app entry point; creates shared view models.
- `ContentView.swift` — root tab view; connects Board, Plan, Help, Settings, and Undo banner.

### Models and state

- `Models.swift` — core data models and enums: ideas, scheduled events, coordinates, categories, commitment, travel mode, travel status, schedule precision, scheduling/export results.
- `BoardViewModel.swift` — manages idea cards, board positions, groups, sample cards, persistence.
- `ScheduleViewModel.swift` — manages scheduled items, travel legs, MapKit estimates, manual ETA, smart ordering, EventKit export, persistence.
- `DelightUndoViewModel.swift` — single-action undo system, undo banner, clear-burst animation.
- `LocationSearchViewModel.swift` — MapKit local search logic.

### Views

- `BoardViews.swift` — free board UI, board zones, board background, empty state, quick actions.
- `CardViews.swift` — magnet/sticky-note card rendering.
- `ScheduleViews.swift` — plan tab, drop zones, scheduled rows, day summary, route actions, exact-time/manual-travel sheets.
- `AddEditViews.swift` — new-card form, templates, detail editor, duration/cost editors.
- `LocationSearchSheet.swift` — location search UI.
- `MapViews.swift` — route map preview using `MKMapView`.
- `PlanningSettingsView.swift` — plan name, home base, search area, day shape, motion settings.
- `WelcomeHelpView.swift` — first-run help / “how it works” screen.
- `VisualDesign.swift` — cute palette, category colors, shadows, section cards, badges.
- `Helpers.swift` — formatting and haptics helpers.

### Documentation

- `README.md` — this full project overview.
- `AGENTS.md` — instructions for future AI/Codex agents working on this code.
- `PROJECT_STATUS.md` — running status notes and checklist.
- `README_VSCODE_FIRST.md` — quick VS Code-first orientation.
- `PRE_IPHONE_TEST_PLAN.md` — manual test checklist for first simulator/device run.
- `PRE_TEST_BACKLOG.md` — known future ideas and backlog.
- `CHANGELOG_MAGNET_BOARD.md` — chronological development checkpoint summary.
- `INFO_PLIST_NOTES.md` — privacy keys and app capability notes for later Xcode setup.

## Suggested Xcode setup later

Create a new iOS SwiftUI app project in Xcode, then add these Swift files to the app target.

Likely app target settings:

- Platform: iOS
- Language: Swift
- UI: SwiftUI
- Minimum iOS target: ideally iOS 17+ for modern EventKit write-only calendar access, though fallback code exists for older versions.
- Frameworks used: SwiftUI, Foundation, MapKit, CoreLocation, EventKit, UIKit.

### Required privacy strings later

Add calendar and location privacy descriptions to the app target’s `Info.plist`. See `INFO_PLIST_NOTES.md`.

At minimum, expect to need:

- `NSCalendarsWriteOnlyAccessUsageDescription`
- possibly `NSCalendarsUsageDescription` for older OS targets
- location strings only if you later request the user’s actual current location. Current code uses search areas and selected coordinates, not live GPS permission.

## VS Code workflow

This is reasonable to edit in VS Code, especially for source organization and AI/Codex work. But final build/run/signing still needs Xcode or `xcodebuild` on a configured Mac.

Recommended VS Code workflow:

1. Unzip this bundle.
2. Open the `MagnetBoardApp` folder in VS Code.
3. Read `AGENTS.md` and `PROJECT_STATUS.md`.
4. Keep edits small and testable.
5. Avoid sweeping rewrites until the first real Apple-toolchain compile.

## Important design principles

Keep these principles intact:

1. Calendar is an output layer, not the starting point.
2. Loose ideas must be allowed.
3. Rough planning must be honest; do not fake exact times too early.
4. Mistakes must be undoable.
5. The app should feel cute, tactile, and forgiving.
6. Prefer obvious labels over hidden expert controls.
7. Do not over-automate or boss the user around.
8. Smart organization should explain itself and respect user intent.
9. Manual estimates are valid; Maps should not be mandatory.
10. This is a personal gift app first, not a generic productivity SaaS.

## Known limitations before iPhone testing

- Not Xcode-compiled yet from this bundle.
- Some SwiftUI API details may need small cleanup depending on deployment target.
- Gesture feel needs simulator/device testing.
- Haptics may need tuning.
- The cute visual style may need dialing up/down after seeing it on an actual screen.
- Smart ordering is not full route optimization.
- Home-base travel exists, but full “leave home at X / be back by Y” optimization is still basic.
- Multi-plan support is not implemented; the current app has one active board/plan name.
- Calendar export supports updating existing EventKit IDs, but first real EventKit test is still needed.

## Next recommended work after first run

1. Fix compile errors, if any.
2. Test first launch and sample board.
3. Test card creation, drag, edit, delete, undo.
4. Test rough planning and exact-time promotion.
5. Test location search and travel estimates.
6. Test manual travel estimates.
7. Test clear schedule and undo.
8. Tune visual design and gestures.
9. Improve any confusing labels.
10. Only then add bigger features like multiple named boards/plans.

## Current best source checkpoint

This bundled source corresponds to the latest “step 17 / pre-test readiness” checkpoint, plus expanded documentation and agent instructions.
