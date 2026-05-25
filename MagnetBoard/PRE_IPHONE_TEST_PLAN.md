# Pre-iPhone / first-device test plan

Use this as a simple manual test script. The goal is not perfection; it is to catch obvious issues before deeper feature work.

## 1. First launch

- App opens without crashing.
- Welcome/help appears only once.
- Board title shows the plan name if one is set.
- Undo banner is not visible until an undoable action happens.

## 2. Basic board use

- Tap **New idea**.
- Add a custom card with only a title.
- Add a quick-template card such as **Cute café** or **Shopping**.
- Tap a card to edit it.
- Hold a card and move it around.
- Confirm normal scrolling still works when not holding a card.
- Drop a card into a zone and confirm its group/state updates sensibly.

## 3. Rough planning

- Drag a card into **Morning**, **Afternoon**, **Evening**, and **Sometime today**.
- Confirm it does not pretend to be an exact calendar event.
- Mark something as **must happen today**.
- Change a rough item to **must happen this afternoon**.
- Set one item to an exact time.

## 4. Deletion / undo safety

- Delete a scheduled row.
- Undo it.
- Delete an idea card.
- Undo it.
- Clear this day.
- Undo it.
- Clear all scheduled cards.
- Undo it.

## 5. Location and travel

- Set home base in Settings.
- Add/search a real location for two cards.
- Plan both cards.
- Calculate travel.
- Add a manual travel estimate and confirm it overrides map lookup for that leg.
- Turn home-start/home-end toggles on/off and check the day summary changes.

## 6. Smart order and sequence rules

- Add two full meals back-to-back and confirm the warning appears.
- Add multiple bar stops and toggle bar crawl on/off.
- Add multiple shopping stops and toggle shopping run on/off.
- Use Make it flow and check that exact/locked items are not moved.

## 7. Cute/delight feel

- Drag a card and check whether the lift/shadow/rotation feels good.
- Clear a schedule and check whether the playful burst is cute or too much.
- Turn on **Reduce playful motion** and confirm the app feels calmer.

## 8. Parents/wife simplicity check

Give the phone to someone and say only:

> Make a few cards and put them into a rough plan.

Watch where they hesitate. Those spots should become the next UI fixes.
