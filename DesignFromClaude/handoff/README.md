# Handoff — Countdown Float (macOS)

## What is in this package

| File | What it is |
|---|---|
| `Countdown Float Reference.dc.html` (project root) | **Cleaned reference.** Only real product UI, interactive: draggable float, hover controls, setup panel, menu, completion toast, menu bar extra. Open in a browser. |
| `handoff/design-spec.md` | Every measurement, color, opacity, blur, radius, shadow and animation, resolved to absolute values. |
| `handoff/ui-states.png` | Visual reference: both display modes in normal / hover / paused / urgent / completed, both setup modes, the menu, the menu bar extra and the toast. |
| `Countdown Float.dc.html`, `Countdown Float v1/v2.dc.html` (project root) | Earlier demo versions, kept for history. They contain the simulated desktop — do not use them as the reference. |

No SwiftUI or AppKit code is included; the native architecture is your call.

## What is product UI

These surfaces ship in the app and the spec covers them fully:

1. **Float window** — always-on-top, frameless, draggable, translucent. Two display modes, Bar and Ring; one is active at a time, chosen in the setup panel.
2. **Hover controls pill** — appears over the float's top-right corner on pointer-over: `⋯` reconfigure, `✕` hide.
3. **Setup panel** — 312 pt panel with the two input modes (At a time, Duration), optional span/start-time reference, optional label, display-mode chips, Start.
4. **Menu** — opened from the menu bar extra: show/hide float, change, pause/resume, add 5 min, cancel.
5. **Menu bar extra** — status dot plus remaining time, always visible while a countdown runs (including when the float is hidden).
6. **Completion toast** — fires at zero, with Add 5 min and End. In the native app this is a user notification; the design shows the intended content and hierarchy, not necessarily a custom window.

## What exists only for presentation

Removed from the cleaned reference, and not to be built:

- The **simulated desktop wallpaper**. The reference keeps a light gradient behind everything for one reason: the float, panels and toast are frosted glass, and their look only reads over a real backdrop. On macOS the backdrop is the user's actual screen content.
- The **fake `notes.md` window** — it existed to prove the float floats above other apps.
- The **simulated macOS menu bar** (Apple menu, File / Window / Help, wall clock, system icons). The system provides all of it. Only the app's own menu bar extra is product UI; in the reference it sits loose at the top right so it can be clicked to open the menu.
- The **bottom hint pill** ("Drag the float · hover for controls…") — demo instructions.
- In `handoff/ui-states.png`: the page heading, the section labels (FLOAT — BAR MODE etc.) and the dark caption pills next to each specimen.
- The **1440 × 900 frame** the reference draws in. It stands for a screen; the float's position within it is arbitrary and freely draggable.

## Notes for implementation

- Glass values in the spec are CSS `backdrop-filter` numbers (blur radius, saturation). Map them to the platform's material of nearest weight, then compare against `handoff/ui-states.png` rather than matching the numbers literally — CSS blur radius ≈ 2 × Gaussian sigma.
- The float's edge is a 1 px inset hairline, not a border that adds to its size; the urgent and completed treatments are overlays drawn inside the same rounded rect, so the float's layout never shifts — only `scale(1.07)` grows it.
- The time readout is tabular-figure Inter at weight 500; the digits must not reflow as they change.
- Hiding the float must not stop the countdown. The menu bar extra keeps counting, and the completion alert still fires.
- `handoff/ui-states.png` was captured with an HTML-to-image renderer; the frosted layers are approximate there, and the Bar/hover specimen's digits are partly overdrawn by that renderer. The interactive reference is the source of truth for anything the PNG makes ambiguous.
