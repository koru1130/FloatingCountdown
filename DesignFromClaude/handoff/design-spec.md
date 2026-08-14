# Countdown Float — design specification

All values are resolved: no design-system variables, no `color-mix()`, no relative units.
Lengths are CSS px at 1× (points on macOS, 1 pt = 1 px here). Colors are sRGB.

Source of truth: `Countdown Float Reference.dc.html` (interactive, product UI only).
Visual reference: `handoff/ui-states.png`.

---

## 1. Foundations

### Typography
| Role | Family | Size | Weight | Line height | Tracking | Numerals |
|---|---|---|---|---|---|---|
| Float time — Bar | Inter, system-ui | 30 | 500 | 1.0 | −0.02em (−0.6) | tabular |
| Float time — Ring | Inter, system-ui | 20 | 500 | 1.0 | −0.02em (−0.4) | tabular |
| Float caption line | Inter | 11 | 400 | 1.55 | 0 | tabular |
| Panel title | Inter | 16 | 500 | 1.12 | −0.015em (−0.24) | — |
| Menu item | Inter | 13.5 | 400 | 1.55 | 0 | — |
| Toast title | Inter | 15 | 400 | 1.55 | 0 | — |
| Toast / help body | Inter | 12.5 / 11.5 | 400 | 1.55 | 0 | — |
| Field label | Inter | 12.5 | 400 | 1.55 | 0 | — |
| Input value | Inter | 14 (17 for the target-time field) | 400 | 1.55 | 0 | tabular |
| Section label (uppercase) | Inter | 11 | 400 | 1.55 | 0.08em (0.88) | — |
| Button label | Inter | 14 | 500 | 1.2 | 0 | — |
| Menu bar extra | Inter | 12.5 | 400 | 1.0 | 0 | tabular |

Fallback chain: `Inter → system-ui → sans-serif`. Body weight 400; every 500 is a medium, never bolder.

### Spacing scale (used verbatim)
2.8 · 5.6 · 8.4 · 11.2 · 16.8 · 22.4 — plus the literal float values 3, 7, 12, 13, 16.

### Radii
4 (chips, menu items) · 5 (segmented option, menu bar extra) · 8 (inputs, buttons, segmented track) · 14 (float, setup panel, menu, toast) · 999 / fully round (controls pill, status dot).

### Palette (resolved)
| Token name in the design | Hex / rgba | Used for |
|---|---|---|
| text | `#e9e9ed` | primary text, float time |
| text 55% | `rgba(233,233,237,0.55)` | captions, help text |
| text 45% | `rgba(233,233,237,0.45)` | input placeholders |
| divider | `rgba(233,233,237,0.16)` | input + chip borders |
| hairline edge | `rgba(233,233,237,0.13)` / `0.12` / `0.14` | float edge / panel edge / controls-pill edge |
| separator | `rgba(233,233,237,0.10)` | menu separator |
| track (bar) | `rgba(233,233,237,0.13)` | progress bar track |
| track (ring) | `rgba(233,233,237,0.14)` | progress ring track |
| neutral 400 | `#b2b6ca` | field labels, paused time, unselected chip text, destructive menu item |
| neutral 500 | `#9397ab` | unselected segmented option |
| neutral 600 | `#75798c` | close glyphs |
| surface | `#232532` | input fill |
| ground | `#161826` | reference only (not painted by the app) |
| accent | `#9184d9` | progress fill, primary button, status dot, completed ring |
| accent 400 | `#b5abfc` | urgent progress fill + urgent edge |
| accent 300 | `#d2cefd` | menu bar extra text, toast kicker |
| accent 200 | `#e7e5fe` | urgent / completed time text, selected chip text |
| accent tints | `rgba(145,132,217,0.14 / 0.16 / 0.18 / 0.22 / 0.26 / 0.28 / 0.4)` | overlays, hovers, selected fills |
| glow (urgent) | `rgba(181,171,252,0.40)` | urgent outer glow |
| glow (completed) | `rgba(145,132,217,0.55)` | completed outer glow |
| shadow ink | `rgba(0,0,0,0.45 / 0.5 / 0.6)` | pill / float / panel drop shadows |

No pure black or white anywhere except inside shadow colors.

---

## 2. Float window

### Shared shell
- Corner radius **14**.
- Fill `rgba(30,32,46,0.52)`.
- Backdrop: **blur 26**, **saturate 150%** (CSS `backdrop-filter: blur(26px) saturate(150%)`). CSS blur radius 26 ≈ Gaussian sigma 13.
- Edge: 1 px inset hairline `rgba(233,233,237,0.13)`.
- Drop shadow: offset y **14**, blur **34**, color `rgba(0,0,0,0.5)`, spread 0.
- Cursor `grab`; whole surface is the drag handle. Text is non-selectable.
- Transitions: `width .2s ease, padding .2s ease, transform .2s ease`.
- Tick rate 200 ms.

Optional glass variants (design props, default = medium above):
- **Sheer**: extra layer, blur 4, inset hairline `rgba(13,14,23,0.35)`, fill `rgba(13,14,23,0.001)`.
- **Solid card**: opaque overlay `rgba(22,24,38,0.62)` on top of the shell fill.

### Bar mode (default)
- Padding **13 / 16 / 12 / 16** (top / right / bottom / left); width intrinsic (hugs content).
- Vertical stack, gap **7**, left-aligned, `width: fit-content`.
- Time: 30 / 500 / tabular / tracking −0.02em.
- Progress bar: height **2**, radius **2**, full-width of the stack, track `rgba(233,233,237,0.13)`, fill = progress color, radius 2, grows from the left edge, width = remaining fraction × 100%.
- Caption line: 11, fixed height **16**, single line, ellipsis on overflow.
- Typical rendered size at `18:42`: ≈ 116 × 84.

### Ring mode
- Width **108** fixed, padding **13** all sides.
- Centered stack, gap **7**.
- Ring box **82 × 82**. SVG viewBox `0 0 100 100`, circle `cx 50 cy 50 r 44`, stroke width **6**, round cap.
- Circumference 276.46 (the design uses the literal **276.5** as dash array); dash offset = 276.5 × (1 − remaining fraction).
- Ring transform `rotate(-90deg) scaleY(-1)`: seam at 12 o'clock, arc **consumes clockwise**.
- Track `rgba(233,233,237,0.14)`; arc = progress color.
- Centered time: 20 / 500 / tabular / tracking −0.02em.
- No caption line in Ring mode.
- Rendered size: 108 × 108.

### Float state table
| State | Time color | Progress color | Overlay | Transform |
|---|---|---|---|---|
| Normal (running) | `#e9e9ed` | `#9184d9` | none | `scale(1)` |
| Paused | `#b2b6ca` | `#9184d9` (frozen) | none | `scale(1)` |
| Urgent (≤ 5 min left) | `#e7e5fe` | `#b5abfc` | inset 1.5 px `#b5abfc`; outer glow blur 28 `rgba(181,171,252,0.40)`; fill `rgba(145,132,217,0.16)` | `scale(1.07)` |
| Completed (past zero) | `#e7e5fe` | `#b5abfc` (bar at 0%, ring full) | inset 1.5 px `#9184d9`; outer glow blur 34 `rgba(145,132,217,0.55)`; fill `rgba(145,132,217,0.14)`; **pulses opacity 0.25 ↔ 0.85, 1.1 s, ease-in-out, infinite** | `scale(1.07)` |

Caption line text: `ends HH:MM` while running · `Paused` · `over time` after zero · `label · HH:MM` when a label is set.

### Hover controls pill
Shown only while the pointer is over the float (a design prop can pin it always-on).
- Anchored **top −11, right −8** relative to the float (overhangs the corner).
- Padding 3, gap 3, fully round, fill `rgba(22,24,38,0.82)`, blur **14**, edge 1 px `rgba(233,233,237,0.14)`, shadow y 6 blur 16 `rgba(0,0,0,0.45)`.
- Two round buttons **20 × 20**: `⋯` (reconfigure, glyph 12) and `✕` (hide float, glyph 11). Glyph color `#e9e9ed`; hover fill `rgba(145,132,217,0.4)`.
- Appears with the *rise* animation, 0.12 s ease-out.
- Mouse-down on these buttons must not start a drag.

### Drag
Position is free; the reference clamps to the work area with margins: x ∈ [8, screenWidth − 222], y ∈ [34, screenHeight − 120]. Position should persist across launches.

---

## 3. Setup panel

- Width **312**, padding **16.8**, radius **14**.
- Fill `rgba(35,37,50,0.86)`, blur **30**, saturate **140%**.
- Edge 1 px `rgba(233,233,237,0.12)`; shadow y 18 blur 44 `rgba(0,0,0,0.6)`.
- Entry: *rise* — opacity 0→1, translateY −6→0, 0.16 s ease-out.
- Header: title 16/500; close `✕` 15 `#75798c`, hover `#e9e9ed`. Margin below header 11.2.

**Mode switch (segmented, 2 up)**: track radius 8, fill `rgba(22,24,38,0.7)`, padding 3, gap 3. Option radius 5, padding 6 vertical, 13 px label. Selected: fill `rgba(145,132,217,0.26)`, text `#e9e9ed`. Unselected: transparent, text `#9397ab`. Margin below 16.8.

**Duration mode**
- Preset row: 4 equal columns, gap 5.6. Chip padding 7 vertical, radius 4, 13 px tabular. Unselected: transparent, 1 px `rgba(233,233,237,0.16)`, text `#b2b6ca`. Selected: fill `rgba(145,132,217,0.22)`, border `#9184d9`, text `#e7e5fe`. Values 5 / 15 / 25 / 60 min.
- Custom row: label 12.5 `#b2b6ca`, gap 8.4, number input width **84**, right-aligned, tabular, range 1–600, suffix `min`.
- Full span row: same shape, placeholder `—`, range 1–1440, help text 11.5 muted.

**At-a-time mode**
- Target time field: full width, value size **17**, tabular. Help text 11.5 muted: "A time already past counts as tomorrow."
- Start time field: width **108**, tabular, optional. Help text 11.5 muted.

**Inputs (all)**: min-height **36**, padding 6 / 10, radius 8, fill `#232532`, border 1 px `rgba(233,233,237,0.16)`, text `#e9e9ed`, placeholder `rgba(233,233,237,0.45)`, caret `#9184d9`. Hover border `rgba(233,233,237,0.45)`. Focus border `#9184d9` (keyboard focus elsewhere: 2 px `#9184d9` ring, 2 px offset).

**Label field**: full width, placeholder "Label (optional)", margin below 11.2.

**Float style**: section label 11 uppercase 0.08em muted, margin below 5.6; two chips (`Bar`, `Ring`) using the preset-chip styling above.

**Footer**: `Start` button fills the remaining width — 14/500, padding 5.6 / 10.08, radius 8, text and 1 px border `#9184d9`, transparent fill; hover fill `rgba(145,132,217,0.12)`, pressed `rgba(145,132,217,0.22)`. To its right, a muted 11.5 tabular hint: resulting duration and end clock (`25:00 · ends 15:26`).

---

## 4. Menu (from the menu bar extra)

- Width **232**, padding **8.4**, radius 14, same glass as the setup panel, same rise animation (0.16 s).
- Items: 13.5, text `#e9e9ed`, padding 7 vertical / 11.2 horizontal, radius 4, left-aligned; hover fill `rgba(145,132,217,0.18)`.
- Order: `Hide float` / `Show float` (toggles) · `Change…` · `Pause` / `Resume` / `Reset` · `Add 5 min` · separator · `Cancel countdown`.
- Separator: 1 px `rgba(233,233,237,0.10)`, margin 5.6 vertical / 11.2 horizontal.
- `Cancel countdown` text `#b2b6ca`.

## 5. Menu bar extra

- Pill: padding 2 / 8, radius 5, fill `rgba(145,132,217,0.16)`, hover `rgba(145,132,217,0.28)`.
- Content: 6 px round dot `#9184d9`, gap 6, then the remaining time — 12.5, tabular, `#d2cefd`. Shows `Set` when no countdown is running.

## 6. Completion toast

- Width **300**, padding 11.2 / 16.8, radius 14.
- Fill `rgba(35,37,50,0.9)`, blur **30** (no saturation boost).
- Edge 1 px `rgba(145,132,217,0.5)`; shadow y 18 blur 44 `rgba(0,0,0,0.6)`.
- Entry: rise, 0.2 s ease-out.
- Kicker `COUNTDOWN` — 11, 0.08em, uppercase, `#d2cefd`; close `✕` 13 `#75798c` → `#e9e9ed`.
- Title 15 `#e9e9ed`, margin below 5.6. Body 12.5 `rgba(233,233,237,0.55)`, margin below 11.2.
- Actions, gap 5.6: `Add 5 min` (secondary — 12.5, padding 5 / 10, radius 8, 1 px `rgba(233,233,237,0.16)`, text `#e9e9ed`) and `End` (ghost — 12.5, text `#9184d9`, no border).

---

## 7. Behavior constants

| Constant | Value |
|---|---|
| Tick | 200 ms |
| Urgent threshold | 5 min (design prop range 0–30) |
| Extend action | +5 min (300 000 ms), also extends the progress denominator |
| Time format | `mm:ss`, `h:mm:ss` past one hour; seconds rounded up |
| Overflow format | `+mm:ss`, counting up, no cap |
| Progress fraction | `clamp(remaining / span, 0, 1)`; span = "Full span" or start-time span when given, otherwise the whole countdown |
| Past target time | counts as tomorrow (+24 h) |
| Hide | hides the float only; the countdown keeps running and the menu bar extra keeps updating |
| Cancel | clears the countdown and reopens the setup panel |

## 8. Animation definitions

- **rise**: `opacity 0 → 1`, `translateY −6 → 0`, ease-out. 0.12 s (controls pill) / 0.16 s (setup, menu) / 0.2 s (toast).
- **flash** (completed float overlay): `opacity 0.25 → 0.85 → 0.25`, 1.1 s, ease-in-out, infinite.
- Float geometry changes (mode switch, urgent scale): 0.2 s ease.
