# Magnet Board App — Project Status

## Product north star

Magnet Board is a playful, forgiving iPhone planning board. The user can dump loose ideas into a sticky-note style board, arrange them visually, promote some of them into rough day plans, make only the confirmed ones exact, and optionally export exact plans to Apple Calendar.

The app should feel like moving little magnets or sticky notes, not like filling out a calendar spreadsheet.

## Completed through Step 14

1. Fixed free-board drag compounding by storing each card's drag start position.
2. Replaced unsafe direct MapKit cycling usage with app-level `TravelMode` and a safe fallback.
3. Moved Apple Calendar permission to export only.
4. Replaced double-optional travel ETA state with explicit `TravelLegStatus`.
5. Added manual travel estimates as first-class alternatives to Maps estimates.
6. Added activity categories: meal, snack/coffee, bar, shopping, exercise, hike, culture/museum, errand, appointment, rest, nightlife, etc.
7. Added soft sequence-rule toggles for meals, high-energy activities, bar crawls, shopping runs, and snack buffers.
8. Added repeatability control so generic ideas can be scheduled multiple times while one-off commitments do not duplicate accidentally.
9. Added semi-structured planning precision: day-only, day-part, and exact time.
10. Fixed open-slot collision detection with real interval overlap logic.
11. Calendar export now updates an existing EventKit event when possible instead of always duplicating.
12. Free-board zones now update card group/state when cards are dropped on the board.
13. New cards can no longer manually claim to be scheduled/locked without a real scheduled placement.
14. Added MapKit location search/geocoding through `LocationSearchViewModel` and `LocationSearchSheet`.
15. Improved scroll-vs-drag behavior and added lifted-card drag feedback.
16. Added more physical drag previews/drop target feedback.
17. Split the oversized `ContentView.swift` into smaller Swift files.
18. Persisted sequence-rule settings with `@AppStorage`.
19. Added category-aware Make it flow for rough plans, including light straight-line coordinate awareness.
20. Added undo for destructive actions.
21. Added clear-this-day and clear-all-scheduled actions with undo.
22. Added playful clear feedback and haptic hooks.
23. Added swipe-to-delete for scheduled rows.
24. Added first-run help / Help screen.
25. Added clearer Board and Plan actions.
26. Added quick-start templates.
27. Added Move Earlier / Move Later for scheduled rows.
28. Added configurable Planning Settings: home base, search area, search radius, and reduce-motion.
29. Added drag-to-reorder for planned rows.
30. Added basic accessibility labels/hints.
31. Added optional home-base travel legs: home → first stop and last stop → home.
32. Added a Day Summary card with stops, activity time, known travel time, rough-card count, must-do count, missing-location hints, and home-base travel notes.
33. Made Make it flow return clearer explanation notes.
34. Added more friendly quick templates: brunch, date night, parents visit, rainy-day backup, bar crawl.
35. Added a Sample button to populate a demo board without wiping existing cards.
36. Added per-scheduled-item “must happen” state so a card can mean “must happen today” or “must happen this afternoon/evening” without requiring an exact time.
37. Added an editable plan name so the board can feel like “Weekend with parents,” “Date night,” or another real human plan.
38. Added soft day start/end preferences in Settings and day-shape warnings for exact events outside the preferred window.
39. Added a shareable plain-text day summary through the Plan screen Share button.
40. Added row actions to convert an exact/rough item back into “sometime today,” “morning,” “afternoon,” “evening,” or “must happen this afternoon/evening” without forcing exact times.
41. Added sample-card duplicate protection so tapping Sample does not endlessly create repeated demo cards.
42. Added an empty-board prompt with “New idea” and “Cute starter board” actions.

## Current strongest areas

- The core mental model is much clearer: loose board → rough plan → exact time → optional calendar export.
- The app is now safer: destructive actions have undo.
- The app is more fun: haptics, lifted cards, clear animation, and friendlier templates.
- The app is more useful: categories, rules, manual ETA, Map ETA, home base, and summary information all exist.

## Honest limitations

- This code has not been compiled in Xcode in this environment. SwiftUI/MapKit/EventKit must still be checked on a Mac/iPhone.
- Home-base travel works from stored coordinates, and Settings now has soft day start/end preferences, but there is not yet a dedicated “leave home at exactly X” workflow.
- Make it flow is still conservative. It is not full route optimization and does not call MapKit for every permutation.
- Drag-to-reorder and drag-on-board feel need real device testing.
- The Sample button now avoids adding duplicate demo titles, but it still uses simple title-based deduping rather than a true sample-set ID.
- Accessibility is improved, not fully audited.
- The UI is friendlier but still needs a final “wife/parents usability pass” after device testing.

## Recommended next non-Xcode steps

1. Add true saved boards/plans instead of only one editable plan name.
2. Add a dedicated “leave home around X / be back by Y” workflow that can influence home-base travel and warnings more directly.
3. Add a printable/shareable pretty itinerary view if the plain-text Share summary feels too basic.
4. Improve the first-run sample/demo flow so a new user can start with either a blank board or a friendly guided example.
5. Continue polishing wording, button sizes, and first-run clarity.
6. Add richer route-aware planning once the basic sticky-note workflow feels good on-device.

## Step 15 notes - home-base and iPhone gesture polish

Completed in this pass:
- Added toggles for whether a planned day should start from the home base and/or end back at the home base.
- Day summary now gives useful home-base timing hints when exact first/last stops and travel estimates are available, such as when to leave home and when the user will likely be back home.
- Share summary now includes home-base travel lines when they are available.
- Free-board cards are now more iPhone-friendly: tap edits, touch-and-hold lifts, then drag moves the sticky note.
- Board-mode cards no longer advertise system drag/drop; compact cards in Plan mode still do, which reduces gesture conflict on the free board.
- Board cards now show a small “Tap to edit · hold to move” hint and lift/rotate/shadow more clearly when picked up.

Still needs device testing:
- The exact feel of the long-press duration on a real iPhone.
- Whether the board hint is helpful or visual clutter.
- Whether home-base timing should be promoted from the summary into stronger warnings.

## Step 16 notes - cute visual design pass

Completed in this pass:
- Added `VisualDesign.swift` as a central place for the cute/pastel visual language.
- Added category emojis and category tint/wash colors, so cards immediately feel more playful and easier to scan.
- Added board-group emojis, soft tinting, and little “pin dot” accents so notes feel more like physical magnets/sticky notes.
- Updated magnet cards with softer gradients, bigger category emoji anchors, stronger paper-like shadows, and repeat badges.
- Updated the free board with a warm pastel background and subtle doodles/hearts/sparkles so it feels less clinical.
- Updated board zone labels with emojis and soft colored backgrounds.
- Updated scheduled rows so planned items carry their category emoji/color into the itinerary.
- Updated drop zones and day summary card with softer pastel styling.
- Made quick-start template buttons feel more like little friendly chips instead of plain form buttons.

Honest notes:
- This is a visual/code-level design pass only; it still needs real iPhone testing to decide whether the pastel styling is cute or too busy.
- The visual design intentionally avoids custom assets for now, so it stays simple SwiftUI and easy to modify.
- A later pass could add a real app icon, custom illustrations, or a theme picker, but those are not necessary before testing the app flow.

## Step 17 — pre-test readiness and cute templates

Completed in this checkpoint:

- Added more wife-friendly quick templates: Cute café, Vintage/thrift shops, Walk by the water, Hair appointment.
- Expanded the sample board with more realistic/cute starter cards.
- Added `README_VSCODE_FIRST.md` for VS Code / source-bundle workflow.
- Added `PRE_IPHONE_TEST_PLAN.md` as a practical manual test script.
- Added `PRE_TEST_BACKLOG.md` for likely post-device-test refinements.

Honest note: this step intentionally avoided deeper feature risk. The app is now at a good point for a first device/simulator test once the Apple build environment is available.
