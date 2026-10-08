# Flutter V2 — Phase 08: Custom schedules and flexible weekday mapping

## Goal
Reach functional parity with the legacy multi-schedule editor while preserving the teacher-assistant data model.

## Included
- Create a blank custom school schedule.
- Duplicate any existing schedule into a new custom schedule.
- Rename and delete custom schedules.
- Built-in Normal and Ramadan schedules remain protected from deletion/rename.
- Assign any saved schedule to any weekday, or mark the day Off.
- Ramadan mode only substitutes the built-in Normal schedule; custom weekday schedules remain unchanged.
- Add teaching periods to any schedule.
- Edit period name, start time and duration.
- Delete periods from schedules.
- Periods are automatically sorted by start time.
- Reject overlapping periods and periods that would end after midnight.
- My Classes only enables cells for periods that actually exist in that weekday's effective schedule.
- Teacher assignments are preserved when a schedule/period is removed; they become inactive instead of being silently deleted.
- Current/next class calculations, bell state and personal notifications continue to derive from the effective weekday schedule.
- Custom schedules are already covered by the existing Flutter V2 backup schema.

## Period IDs
Teacher assignments continue to reference stable period IDs such as p1, p2, p3. A newly added teaching period uses the lowest unused p-number inside that schedule. This means:
- a blank custom schedule starts with p1,
- the Normal schedule adds p7 after p1..p6,
- the default Ramadan schedule adds p6 after p1..p5.

## Version
2.7.0+16
