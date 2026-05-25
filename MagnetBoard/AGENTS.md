# AGENTS.md — Magnet Board Planner

These are working instructions for future AI coding agents, Codex sessions, or human contributors editing this project.

## Project identity

Magnet Board Planner is a SwiftUI iPhone/iPad app for playful visual planning. It is a personal gift app first. The emotional goal matters: it should feel cute, forgiving, intuitive, and fun to use.

The app should feel like moving sticky notes or magnets around a board, not like filling out a spreadsheet or fighting a rigid calendar.

## Non-negotiable product principles

1. **Do not turn this into a normal calendar app.**
   Calendar export is an output mode only.

2. **Support uncertainty.**
   Users should be able to create vague cards like “cute café” or “go somewhere fun for dinner.” Do not force exact time, duration, location, or coordinates too early.

3. **Preserve the planning gradient.**
   The desired flow is:
   `loose idea → detailed idea → rough plan → must-happen rough plan → exact event → calendar export`

4. **Manual estimates are valid.**
   Do not require MapKit or exact coordinates just to make a plan useful. A user should be able to say “this takes about 20 minutes” and move on.

5. **Mistakes should be recoverable.**
   Destructive actions should support undo. Avoid scary irreversible actions.

6. **Keep it cute but usable.**
   Pastels, emojis, shadows, and playful animation are welcome, but do not sacrifice clarity or accessibility.

7. **Prefer obvious UI.**
   Use visible buttons and plain-language labels for important actions. Do not hide everything behind tiny icons or long-press-only behavior.

8. **Be honest in warnings.**
   If the app only has rough data, say so. Do not pretend rough plans are exact itineraries.

9. **Do not overclaim smart ordering.**
   Current Make it flow is lightweight and conservative, not a full route optimizer.

10. **Keep source changes small and reversible.**
    This app has grown quickly. Avoid large rewrites until after first Xcode/device testing.

## Current architecture

The code is intentionally split into small Swift files:

- `MagnetBoardApp.swift` — app entry point and environment objects.
- `ContentView.swift` — root tab view.
- `Models.swift` — core data models and enums.
- `BoardViewModel.swift` — idea-card state and board persistence.
- `ScheduleViewModel.swift` — schedule state, travel, smart ordering, calendar export.
- `DelightUndoViewModel.swift` — undo and playful clear feedback.
- `LocationSearchViewModel.swift` — MapKit local search.
- `BoardViews.swift` — free board UI.
- `CardViews.swift` — card UI.
- `ScheduleViews.swift` — plan UI.
- `AddEditViews.swift` — create/edit card UI.
- `LocationSearchSheet.swift` — location search UI.
- `MapViews.swift` — MapKit route map.
- `PlanningSettingsView.swift` — plan/home/search/day-shape/motion settings.
- `WelcomeHelpView.swift` — first-run help.
- `VisualDesign.swift` — visual style helpers.
- `Helpers.swift` — formatting/haptics helpers.

## Current state model

### Idea cards

`IdeaItem` represents a source card on the board. Important properties include:

- title
- duration
- cost
- location name
- coordinate
- notes
- tags
- people
- priority
- board position
- board group
- commitment
- category
- repeatability

### Scheduled items

`EventItem` represents an item placed into a plan/day. Important properties include:

- source idea ID
- title
- location
- coordinate
- category
- start/end proxy date
- schedule precision
- daypart
- must-happen flag
- locked flag
- manual travel estimate to next stop
- EventKit ID after export

### Rough timing

Do not assume all scheduled items are exact. The app intentionally supports:

- day-only rough placement
- daypart rough placement
- exact-time placement

Exact times are needed for Apple Calendar export.

## Coding guidelines

### SwiftUI style

- Prefer simple SwiftUI views over clever abstractions.
- Keep tap targets large enough for normal iPhone use.
- Use plain labels where helpful.
- Add accessibility labels/hints when creating new controls.
- Use `@AppStorage` only for simple settings.
- Keep persistence JSON-compatible.

### Data compatibility

When adding non-optional fields to `IdeaItem` or `EventItem`, update custom decoding so older saved JSON continues to load.

Default old/missing values gently. Do not break old test data.

### Travel logic

Use the app-level `TravelMode` enum. Do not directly add unsupported MapKit transport cases.

Cycling currently falls back safely because public MapKit support may vary by SDK/deployment target.

Travel states should remain explicit. Prefer `TravelLegStatus`-style states over nested optionals.

### Calendar logic

Calendar permission should only be requested at export time. Do not request calendar permission on app launch.

Only exact-time events should export to Apple Calendar.

If an event already has an EventKit ID, update it where possible instead of creating duplicates.

### Deletion and undo

Before adding any new destructive action, add undo or a safe confirmation path.

Current undo is single-action undo, not a full stack. Keep this clear in UI and docs.

### Visual design

Use `VisualDesign.swift` helpers when possible instead of hard-coding random colors.

The current style is intentionally warm/pastel/cute:

- category emojis
- soft card backgrounds
- paper-like shadows
- doodly board background
- playful clear animation

If tuning visuals, prefer centralized changes in `VisualDesign.swift`.

## Build/testing reality

This source has not yet been verified in Xcode. Do not claim it compiles until it has been compiled with an Apple toolchain.

Expected first-run tasks:

1. Create/open an Xcode SwiftUI iOS app project.
2. Add all Swift files to the app target.
3. Add required privacy strings.
4. Build.
5. Fix compile errors one at a time.
6. Test on simulator.
7. Test on real iPhone.

## Required privacy/capability notes

Calendar export needs EventKit privacy text. See `INFO_PLIST_NOTES.md`.

Location search using MapKit local search does not necessarily require live-location permission unless the app requests the user’s actual current location. If adding GPS/home-current-location features later, add the appropriate location usage descriptions.

## High-priority backlog after first compile

1. Fix compile errors.
2. Test and tune iPhone gestures.
3. Test haptics.
4. Test undo/clear behavior.
5. Test EventKit export/update.
6. Test MapKit search and routing.
7. Tune visual density/cuteness.
8. Improve accessibility.
9. Add multiple named plans/boards.
10. Improve route-aware optimization.

## Things to avoid

- Do not remove rough planning just to simplify code.
- Do not require coordinates for all cards.
- Do not request permissions before the user does something that needs them.
- Do not make smart ordering silently override locked/exact commitments.
- Do not make destructive actions permanent without undo.
- Do not do a massive refactor and feature addition in the same pass.
- Do not claim device-tested behavior without device testing.

## Suggested agent workflow

For each coding pass:

1. State the exact item being changed.
2. Make the smallest coherent edit.
3. Update `PROJECT_STATUS.md` or docs if behavior changes.
4. Preserve existing behavior unless intentionally changing it.
5. List honest limitations.
6. Produce a new zip/checkpoint if handing off.

## User preference / tone notes

The owner values honest progress over fake completeness. Be transparent about uncertainty, compile risk, and limitations. Full drop-in replacements are preferred over vague patch descriptions when practical.

