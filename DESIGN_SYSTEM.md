# Checkfuchs — UI Design System

Prescriptive UI/UX conventions for the app. **New or changed UI must conform to these.**
A Flutter + Material 3 app, dark *and* light, built before the screens so we never have
to retro-align (the lesson from knabberfuchs). Anchored on the data model in
[`design-concept.md`](./design-concept.md) — in particular the **anti-rigidity** value,
which the colour system encodes directly (see §1.4, the "no alarm red" law).

> Status: **foundation in progress.** §1 Colour is locked. Typography, spacing/shape, and
> components follow before we mock screens.

---

## 1. Colour

### 1.1 The triad
The palette is a **triadic scheme** anchored on the fox's tangerine and stepped 120°
around the wheel — harmonious by construction, warm-sunset rather than primary-clash.

| Role (M3) | Name | Hue | Light | Dark |
|---|---|---|---|---|
| **primary** | Fox Orange (Tangerine) | 26° | `#EA7A24` | `#F39C4E` |
| **secondary** | Indigo | 266° | `#8559D0` | `#A98CEE` |
| **tertiary** | Emerald | 146° | `#1FA85D` | `#37CE78` |

- **Fox Orange** — the brand. Primary actions, the **Active** state, FABs, key accents.
- **Indigo** — structure & selection. Secondary controls, the **current lens focus**.
- **Emerald** — positive. Doubles as the **Done** status (one colour, two honest jobs).

### 1.2 Theme strategy
Anchor the three *hues*; let Material 3 generate the tonal ramps per theme.

- **Both themes are first-class** (knabberfuchs convention), driven by
  `MediaQuery.platformBrightness` with a manual override in settings.
- We do **not** use single-seed `ColorScheme.fromSeed` — it derives secondary/tertiary
  from one hue and would collapse the triad. Instead build explicit light/dark
  `ColorScheme`s with the three hues as `primary` / `secondary` / `tertiary` (tonal ramps
  via Material Color Utilities). Single source of truth: `lib/core/theme.dart`.
- The Light/Dark hexes above are the **brand tones**; surrounding tones (containers,
  on-colours) come from each hue's tonal palette.

### 1.3 Status colours — the "no alarm red" law
The model says a `Missed` is **data, not punishment** (concept §1.3). The colour system
**enforces** this: nothing about a task's status is ever allowed to shout.

| State | Meaning | Light | Dark | Treatment |
|---|---|---|---|---|
| **Active** | in its window, open | `#EA7A24` | `#F39C4E` | fox orange — outlined ring / accent |
| **Done** | completed | `#1FA85D` | `#37CE78` | emerald — filled check |
| **Skipped** | deliberately declined (neutral) | `#8C857E` | `#9A938C` | calm grey |
| **Missed** | window passed (automatic) | `#A8988C` | `#B6A79B` | **faded taupe, struck — never red** |
| **Pending** | before its window | `outline` | `outline` | low-emphasis grey |
| **Avoidance** | pushed past threshold | `#E0A33B` | `#EDB45A` | soft amber — *information, not a command* |
| **Lens focus** | current periodic pick | `#8559D0` | `#A98CEE` | indigo |

> **THE LAW: red is reserved exclusively for destructive actions** (deleting a series,
> wiping data) via the M3 `error` role. It must **never** signal task status. A missed
> habit *fades*; it does not bleed. This is the single rule that keeps the app feeling
> calm instead of nagging — break it and the whole anti-rigidity premise dies.

### 1.4 Tints & emphasis
- **Tinted pills/chips** use `color-mix(... 15–18% , transparent)` of the status colour on
  the foreground tone (e.g. the `ACTIVE` pill = 15% fox orange). Keeps accents legible in
  both themes without a second token.
- **Muted text** = `colorScheme.outline` (matches knabberfuchs).
- Avoid large saturated fills of emerald/indigo — they read loudest; prefer them as marks,
  outlines, and small fills, with fox orange carrying the primary weight.

---

## 2. Typography

### 2.1 The typeface is user-selectable (accessibility-first)
There is no single hard-coded font. The user picks the app's base typeface in Settings —
a deliberate accessibility choice, not a vanity feature:

| Option | Role | License / source |
|---|---|---|
| **Figtree** | **Default** — the brand voice (friendly, modern humanist) | OFL · bundled |
| **System** | Native platform font, zero bundle, maximum familiarity | — |
| **Atkinson Hyperlegible** | Accessibility — **low vision**; disambiguates `l/I/1`, `O/0/Q` | OFL · bundled |
| **OpenDyslexic** | Accessibility — **dyslexia**; weighted letterforms | OFL-style · bundled |

- The choice sets the app's base `fontFamily` only; **the M3 type scale (sizes/weights)
  is family-agnostic** and never changes — switching fonts re-skins, never re-flows logic.
- Every family falls back to `system-ui` for any missing glyph.
- **Layouts must tolerate a wider/taller font** (OpenDyslexic is chunky): no fixed-height
  text boxes, no single-line truncation that a larger face would clip. This is good
  accessibility hygiene regardless. Pair with respecting the OS text-scale setting.

### 2.2 Type scale (Material 3 roles)
Use the standard M3 scale; these are the ones we actually reach for:

| Role | Use |
|---|---|
| `headlineSmall` / `titleLarge` | screen titles ("Today"), sheet titles |
| `titleMedium` | task name, lens name |
| `bodyMedium` | secondary text, notes |
| `labelLarge` | buttons |
| `labelSmall` | pills, chips, metadata |

### 2.3 Numbers
**Times, counts, streaks, and "n of m" use tabular figures**
(`fontFeatures: [FontFeature.tabularFigures()]`) so digits don't jiggle as they update.
CSV/export stays plain. Figtree, Atkinson, and System all support tabular; OpenDyslexic
falls back gracefully.

## 3. Spacing, shape & elevation

### 3.1 Shape — soft, friendly rounding
The brand is calm, so corners are generous (we deliberately chose the rounder option —
it sits better with the warm tangerine). One radius scale, no ad-hoc values:

| Token | Value | Used for |
|---|---|---|
| `xs` | 8 | chips, tags |
| `sm` | 12 | buttons, inputs |
| `md` | 16 | small/inner surfaces |
| `lg` | 20 | **cards**, dialogs |
| `xl` | 28 | **bottom sheets** (top corners) |
| `full` | 999 | **pills, FAB**, status badges |

The FAB is a **full pill** (not the M3 16dp default) — a deliberate brand choice for a
softer feel. Buttons are `sm` (12), cards `lg` (20), sheets `xl` (28).

### 3.2 Spacing — one tight scale
Gap vocabulary: **`4 · 8 · 12 · 16 · 20 · 24 · 32`**. No values outside it.

- **Screen inset: 16.**
- **List bottom-padding: 96** (88 for forms) so the FAB never covers the last row.
- **Touch targets ≥ 48dp**; **task/list rows ≥ 56dp** (accessibility + the wider-font rule
  from §2.1).
- Default gap between stacked cards: 12; within a card, 16 insets.

### 3.3 Elevation — flat and quiet
Material's default drop-shadows feel heavy; we keep surfaces calm.

- **Separation = hairline borders** (`colorScheme.outlineVariant`) + a *barely-there* soft
  shadow, not stacked floating cards.
- **The FAB is the only genuinely-elevated element** — a soft orange-tinted glow.
- **Dark mode leans on M3 tonal elevation** (surface tint) rather than shadow.
- Bottom sheets: scrim + drag handle + modest elevation (`isScrollControlled: true`,
  `showDragHandle: true`), full-width primary `FilledButton` at the bottom — same shape
  language as knabberfuchs.

---

## 4. Components

Canonical mockups live in [`examples/ui/`](./examples/ui/) — open in a browser (each has a
light/dark toggle). Until the Flutter widgets exist, the HTML is the visual canon; once
built, each pattern gains a `file:line` pointer to live code (knabberfuchs convention).

### 4.1 State markers (locked)
| State | Icon (Material Symbols Rounded) | Colour |
|---|---|---|
| Active | `radio_button_unchecked` (single ring) | orange |
| Done | `check_circle` (filled) | emerald |
| Skipped | `remove_circle_outline` | muted |
| Missed | `radio_button_unchecked` + struck name | taupe |
| Pending | `schedule` | muted |
| Focus | `center_focus_strong` (filled) | indigo |
| Dormant | `bedtime` | taupe |

### 4.2 Task row → `examples/ui/05-task-detail.html`
- Layout `[marker] name … [hint | pill]`, min height **56**.
- **Tap the marker ring = instant `Done`** (the 80 % action).
- **Swipe** reveals actions — continuous lens: **Done · Skip**; periodic lens: **Done ·
  Skip · Pass**. `Pass` = `arrow_forward` (indigo). **Never a destructive action on swipe.**
- `Missed` row: faded ring + struck taupe name.

### 4.3 Lens card → `examples/ui/04-lens-view.html`
- A `lg`(20) card. Header = lens name + the **text-breakdown summary**
  ("1 done · 1 missed · 1 left", `missed` in taupe, zero parts omitted). **The header
  summarises the *full* lens even in a filtered View** (calm list, honest header).
- Periodic lens: focus row uses the Focus marker + `FOCUS` pill; quota-met → "done this week".

### 4.4 View navigation → `examples/ui/04-lens-view.html`
- Top **scrollable tab row** (Views are user-defined & unbounded → tabs, not bottom-nav);
  active tab = tangerine underline.
- Each `View↔Lens` carries `statusFilter`; the same lens reads differently per View.

### 4.5 Detail sheet → `examples/ui/05-task-detail.html`
- Bottom sheet: `xl`(28) top, drag handle, `isScrollControlled`.
- Prominent name field; **This-occurrence / The-series** segmented (only when recurring).
- Property rows (icon + label + value, drill-in): **Active window** (day/morning/…/time
  chips), **Repeat**, **Reminders**, **Lens**, **Note**.
- Full-width **Save** (`FilledButton`); **Delete** in `error` red — *the one sanctioned
  alarm-red use* (§1.3).

### 4.6 Recurrence editor → `examples/ui/06-recurrence.html`
- Segmented frequency **Off · Day · Week · Month · Year** (Off = one-off).
- **Every-N** stepper; Week → weekday chips; Month → day-of-month + "Last day"; Year →
  month + day; the **Starts** (anchor) row.
- **Live plain-English summary banner** (tangerine tint) at top, restated on every change.
- Ordinal-weekday ("2nd Tuesday") intentionally **out** for v1 (concept §11).

### 4.7 Pills, chips & tints
- Status pill = uppercase `labelSmall`, `full` radius, fill =
  `color-mix(<status> 15–18 %, transparent)`. NOW/ACTIVE tangerine · FOCUS indigo · due amber.

### 4.8 FAB
- **Extended, full-pill** `+ Add`, bottom-right, tangerine — the one elevated element (soft
  orange glow). Unique `heroTag` per screen.

## 4. Components  *(after mocks)*

_TBD — task row, lens card, FABs, input sheets, recurrence/window editor. Each with a
canonical snippet + a `file:line` pointer to the live example, knabberfuchs-style._
