# Magnet Board Planner — Development Checkpoints

This is a condensed development history of the current prototype.

## Initial goal

Build a SwiftUI iPhone planning app that behaves more like a visual magnet board / sticky-note wall than a strict calendar. The app should allow loose ideas, rough planning, exact scheduling, travel estimates, and optional Apple Calendar export.

## Major completed checkpoints

### Step 1 — Free-board drag fix

Fixed a drag compounding bug by storing stable drag start positions rather than adding gesture translation to continuously changing coordinates.

### Step 2 — Safe travel mode

Replaced unsafe direct use of a possible MapKit cycling enum with an app-level `TravelMode` enum and safe fallback behavior.

### Step 3 — Calendar permission on export only

Removed launch-time calendar permission request. Calendar access is now requested only when the user exports an exact event.

### Step 4 — Travel-leg model and manual ETA

Replaced nested optional travel-time state with explicit travel-leg status. Added manual travel estimates so Maps is not mandatory.

### Step 5 — Activity categories and sequence rules

Added categories such as full meal, snack/coffee, bar, shopping, hike, culture, errand, appointment, etc. Added soft sequence rule toggles.

### Step 6 — Repeatability and duplicate scheduling control

Added per-card repeatability to prevent accidental duplicate scheduling while allowing intentional repeats like snacks, bars, and shopping stops.

### Step 7 — Semi-structured planning

Added `SchedulePrecision` and `DayPart` so cards can be placed roughly in morning/afternoon/evening/day-only without pretending they have exact times.

### Step 8 — Core fixes

Added interval-overlap logic, calendar update behavior using stored EventKit IDs, board-zone state updates, and prevention of impossible manual scheduled states.

### Step 9 — Usability/location/autoplan

Added MapKit location search, configurable search behavior, better drop targets, split source files, persisted sequence rules, and category-aware smart ordering.

### Step 10 — Delight and undo

Added undo banner, safe deletion, clear-day/clear-all actions, playful clear burst, haptic hooks, improved drag feedback, and swipe-to-delete.

### Step 11 — Clarity and help

Added first-run help, visible Board actions, quick templates, clearer Plan text, Move earlier/later, and lightweight distance-aware smart order.

### Step 12 — Settings, reorder, accessibility

Added planning settings, home/search area settings, drag-to-reorder scheduled rows, accessibility labels/hints, and reduce-motion setting.

### Step 13 — Home base, day summary, must-do planning

Added home-base travel legs, day summary card, must-happen rough planning, more templates, and sample board.

### Step 14 — Plan name, day shape, share summary

Added editable plan name, soft start/end day preferences, shareable text day summary, richer rough timing controls, sample dedupe, and empty-board prompt.

### Step 15 — Gesture polish and home-base toggles

Added start-from-home/end-at-home toggles, home-base departure/return hints, improved board gesture model, and tactile lifted-card feedback.

### Step 16 — Cute visual design

Added `VisualDesign.swift`, category emojis, pastel card washes, board doodles, soft section cards, nicer shadows, and cuter template chips.

### Step 17 — Pre-test readiness

Added more friendly templates, expanded sample board, VS Code notes, pre-iPhone test plan, and pre-test backlog.

## Current recommendation

Do not add major new features until the first Xcode/simulator/device compile-and-test pass. The next highest-value work is compile cleanup, gesture tuning, visual tuning, and real-world usability testing.

## UX polish pass

- Added a UX implementation plan (`UX_IMPLEMENTATION_PLAN.md`).
- Reworded major user-facing labels to feel warmer and less technical.
- Combined smart ordering and travel refresh into one “Make it flow” action.
- Added a plan mood/status pill to the day summary.
- Hid manual latitude/longitude entry behind a developer disclosure.
- Reworded empty-board and starter-board prompts for a more guided first-run experience.
- Reworded warning, drop-zone, duplicate-scheduling, and rough-placement language.
