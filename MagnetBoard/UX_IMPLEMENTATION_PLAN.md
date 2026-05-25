# UX Implementation Plan

This plan keeps the app's core concept intact: users make cute loose cards first, then add structure only when the plan needs it. The goal is to make the app feel friendly and tactile on iPhone while keeping the planning engine available behind simple language.

## Phase 1 — Already implemented in this bundle

### 1. Friendlier product language
- Renamed technical/user-hostile labels into warmer labels:
  - “New Card” → “New idea” / “Blank card”
  - “Smart Order” → “Make it flow”
  - “Travel” folded into “Make it flow”
  - “Sequence rules” → “Planning preferences”
  - “Planning warnings” → “Things to check”
  - “Scheduled” → “In the plan”
  - “Scheduled soon” → “In the plan”
  - “Allow multiple scheduled copies” → “Can use this more than once”
  - “Sometime this day” → “Sometime today”

### 2. More guided board onboarding
- Reworded the empty board into a more intent-based starter prompt: “What kind of day are you making?”
- Reworded the sample board action as a “Cute starter board” so it feels like a useful starting point rather than a developer demo.
- Simplified the board quick-action labels to reduce clutter.

### 3. Cleaner add-card flow
- Reworded the new-card form around “Card basics” and “Optional details.”
- Hid raw latitude/longitude behind a “Developer coordinates” disclosure group.
- Kept the normal user path focused on a place/neighborhood search field.

### 4. Plan dashboard mood
- Added a plan mood/status pill to the day summary:
  - Blank canvas
  - Needs details
  - Packed
  - Flexible
  - Looks tidy
- Added short friendly explanations under the mood so users understand what the app thinks without feeling judged.

### 5. Unified planning action
- Replaced separate “Smart Order” and “Travel” buttons with one primary “Make it flow” action.
- This action now arranges rough events, recalculates travel, and reports what changed.

### 6. Softer warnings and drop targets
- Renamed warning language to “Things to check.”
- Reworded drop targets as soft baskets rather than strict schedule commitments.
- Made duplicate-scheduling language match the new “Can use this more than once” label.

## Phase 2 — Next best UX improvements

### 1. Collapsible card tray
Replace the horizontal loose-card strip with a bottom drawer:
- Closed state: “Card tray · 8”
- Open state: draggable cards in a larger, easier touch target area
- Benefit: reduces vertical crowding and avoids scroll-vs-drag confusion on iPhone.

### 2. Stronger visual distinction for rough/exact/locked rows
Add clearly different scheduled row treatments:
- Rough/daypart rows: soft sticky-note look
- Exact-time rows: firmer calendar-card look
- Locked rows: clipped/pinned visual with a lock accent
- Benefit: users immediately understand what is flexible vs real.

### 3. Actionable warning cards
Replace warning text bullets with mini action cards:
- Add location
- Mark as okay
- Move later
- Set exact time
- Benefit: warnings become helpful next steps instead of passive complaints.

### 4. Starter plan templates
Add starter-board modes:
- Date day
- Visitors in town
- Shopping day
- Chill weekend
- Custom
- Benefit: first-run users get value in seconds.

### 5. Better location UX
Continue moving toward normal place search:
- Show “exact place selected” vs “neighborhood/manual only.”
- Keep manual travel estimates first-class.
- Avoid exposing coordinates outside debug/developer paths.

### 6. Gesture polish
Make drag/drop more tactile:
- Larger drop zones
- Hover expansion/glow
- “Drop here” state
- Better previews that compress into the scheduled row
- Benefit: the app feels physical and forgiving.

## Product principle
The app should feel like making cute sticky notes. The planning intelligence should stay mostly behind the curtain until the user asks for help.
