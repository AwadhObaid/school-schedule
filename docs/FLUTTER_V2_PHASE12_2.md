# Flutter V2 Phase 12.2 — Visual Identity Refresh

## Goal

Unify the launcher icon, native splash, Flutter splash and application theme under the approved green visual identity.

## Approved palette

- Primary green: `#2F7D5A`
- Mint container: `#DDEEE4`
- Light background: `#F6FAF7`
- White surface: `#FFFFFF`
- Primary text: `#173B2D`
- Secondary text: `#63736A`
- Outline: `#D5E2DA`
- Accent gold: `#D4A95F`

Dark identity:
- Background: `#101A15`
- Surface: `#18251E`
- Primary: `#79C69D`
- Primary container: `#244C38`
- Text: `#ECF5EF`
- Secondary text: `#B5C6BB`

## Changes

- Removed the navy brand color from the Flutter splash.
- Splash content is explicitly centered using a full-screen Stack/Align layout.
- Loading indicator now uses the application primary green.
- Native Android splash uses the same light/dark backgrounds.
- Launcher adaptive background is green.
- The launcher artwork is regenerated as a green gradient icon with the white clock/schedule mark.
- Light and dark ThemeData now explicitly use the approved palette instead of relying only on generated seed colors.
- Existing application functionality and data stores are unchanged.

## Version

2.10.2+21
