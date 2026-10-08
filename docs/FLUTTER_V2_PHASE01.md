# Flutter V2 — Phase 01 Foundation

## Goal
Create a parallel Flutter foundation while preserving the current production Capacitor application unchanged.

## Decisions
1. Keep `com.salaheddine.schedule` so the future signed release can continue the Android app identity.
2. Keep the legacy root project intact during migration.
3. Place the new implementation under `flutter_v2/`.
4. Use Material 3 and Arabic RTL from the first commit.
5. Separate school timing (`SchoolPeriod`) from the teacher's personal assignments (`TeacherClass`).
6. Local-first architecture; no cloud database is required for the current product scope.

## Phase 01 acceptance criteria
- The Flutter project can be bootstrapped on Windows with `tools/bootstrap_flutter_v2.ps1`.
- `flutter analyze` passes.
- `flutter test` passes.
- The initial home shell renders four tabs.
- The legacy root Capacitor/Android app is untouched.

## Next phase
Phase 02 will implement local schedule state and the editable weekly **حصصي** grid, then calculate the current and next teacher class from the real school period times.
