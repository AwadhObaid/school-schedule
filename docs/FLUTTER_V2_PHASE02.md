# Flutter V2 — Phase 02: My Classes

## Goal
Turn the approved Phase 01 shell into a functional teacher assistant driven by the teacher's own weekly assignments and the device clock.

## Included
- Weekly My Classes matrix: Sunday through Thursday, periods 1 through 6.
- Tap a cell to add or edit subject, class/section and optional notes.
- Local persistence using SharedPreferences. No account or cloud database is required.
- Real current-class calculation from the device clock.
- Real countdown to the end of the current class.
- Automatic next-class calculation, including the next school day.
- Home screen driven by saved teacher data instead of demo values.
- Read-only school period screen using the same timing source as the teacher schedule.
- Engine and persistence tests.

## Timing baseline copied from the stable application
- Period 1: 07:45, 35 minutes
- Period 2: 08:25, 35 minutes
- Period 3: 09:05, 35 minutes
- Period 4: 10:05, 35 minutes
- Period 5: 10:45, 35 minutes
- Period 6: 11:25, 35 minutes

The assembly/break periods remain part of the legacy school schedule but are not selectable as teacher classes.

## Safety
The legacy Capacitor app remains unchanged. Flutter V2 continues on its own migration branch until feature parity and signing are verified.
