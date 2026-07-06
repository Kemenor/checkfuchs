# Checkfuchs — UI Design System

**Inherits the [Fuchsbau design system](https://github.com/Kemenor/fuchsbau/blob/main/DESIGN.md).**
Colours (the shared tangerine triad), typography (Figtree + the accessibility font
picker), the spacing/shape/elevation scales, iconography (Material Symbols Rounded), and
base component patterns (pill FAB, 28-sheets, this/series edits, swipe-not-destructive) all
come from there. This doc records only what's **checkfuchs-specific**: how its state model
maps onto the shared palette, and its bespoke screens.

> **Deviations from Fuchsbau: none.** checkfuchs uses the shared colours, fonts, and scales
> as-is.

Flutter + Material 3, dark *and* light. Canonical mockups: [`examples/ui/`](./examples/ui/)
(each has a light/dark toggle). Until the widgets exist, the HTML is the visual canon; once
built, each pattern gains a `file:line` pointer to live code.

---

## 1. Status → colour

checkfuchs's task states (concept §2.2) mapped onto the Fuchsbau palette. The Fuchsbau
**"red is for destruction only"** law applies directly: a `Missed` *fades*, it never
shouts — that's how the model's *anti-rigidity* value (concept §1.3) is encoded in pixels.

| State | Meaning | Light | Dark | Treatment |
|---|---|---|---|---|
| **Active** | in its window, open | `#EA7A24` | `#F39C4E` | fox orange — outlined ring / accent |
| **Done** | completed | `#1FA85D` | `#37CE78` | emerald — filled check |
| **Skipped** | deliberately declined (neutral) | `#8C857E` | `#9A938C` | calm grey |
| **Missed** | window passed (automatic) | `#A8988C` | `#B6A79B` | **faded taupe, struck — never red** |
| **Pending** | before its window | `outline` | `outline` | low-emphasis grey |
| **Avoidance** | pushed past threshold | `#E0A33B` | `#EDB45A` | soft amber — *information, not a command* |
| **Lens focus** | current periodic pick | `#8559D0` | `#A98CEE` | indigo |

- **Tinted pills/chips** = `color-mix(<status> 15–18 %, transparent)` (e.g. the `NOW` pill =
  15 % fox orange); legible in both themes without a second token.
- Prefer emerald/indigo as **marks, outlines, small fills**; fox orange carries the
  primary weight (large saturated emerald/indigo fills read too loud).

## 2. State markers (locked)
Material Symbols Rounded, one coherent set:

| State | Icon | Colour |
|---|---|---|
| Active | `radio_button_unchecked` (single ring) | orange |
| Done | `check_circle` (filled) | emerald |
| Skipped | `remove_circle_outline` | muted |
| Missed | `radio_button_unchecked` + struck name | taupe |
| Pending | `schedule` | muted |
| Focus | `center_focus_strong` (filled) | indigo |
| Dormant | `bedtime` | taupe |

## 3. Components (checkfuchs surfaces)

Base patterns (FAB, sheets, segmented edits) are Fuchsbau's; below is how checkfuchs's
screens use them.

### 3.1 Task row → `examples/ui/05-task-detail.html`
- Layout `[marker] name … [hint | pill]`, min height **56**.
- **Tap the marker ring = instant `Done`** (the 80 % action).
- **Swipe** reveals actions — continuous lens: **Done · Skip**; periodic lens: **Done ·
  Skip · Pass**. `Pass` = `arrow_forward` (indigo). **Never a destructive action on swipe.**
- `Missed` row: faded ring + struck taupe name.

### 3.2 Lens card → `examples/ui/04-lens-view.html`
- A `lg`(20) card. Header = lens name + the **text-breakdown summary**
  ("1 done · 1 missed · 1 left", `missed` in taupe, zero parts omitted). **The header
  summarises the *full* lens even in a filtered View** (calm list, honest header).
- Periodic lens: focus row uses the Focus marker + `FOCUS` pill; quota-met → "done this week".

### 3.3 View navigation
- **Bottom `NavigationBar`**, one destination per View — the Fuchsbau family pattern
  (knabberfuchs navigates the same way) and thumb-reachable for the app's most frequent
  gesture. *(Supersedes the original top-tab-row decision: "Views are unbounded" was
  theoretically right but practically thin — real usage is 2–4 Views, and the unbounded
  case gets an escape hatch instead of dictating the whole design.)*
- Each View carries an **icon** from a curated ~12-slug set (`ui/view_icons.dart`),
  picked at creation; slugs are persisted, so the set only ever grows.
- **Settings is the fixed last destination** (gear), exactly like knabberfuchs; Vacation
  (and later backup/restore) lives *inside* the Settings screen. The bar is always visible.
- Up to **4** View destinations before Settings; beyond that the fourth slot becomes
  **More** (a sheet with the rest).
- **No app-bar overflow menu.** The altitude map: *act on tasks* = list + big FAB ·
  *shape structure* = small FAB's sheet (§3.6) · *configure the app* = Settings tab.
- Each `View↔Lens` carries `statusFilter`; the same lens reads differently per View.

### 3.4 Detail sheet → `examples/ui/05-task-detail.html`
- Bottom sheet (Fuchsbau pattern): `xl`(28) top, drag handle, `isScrollControlled`.
- Prominent name field; **This-occurrence / The-series** segmented (only when recurring).
- Property rows (icon + label + value, drill-in): **Active window** (day/morning/…/time
  chips), **Repeat**, **Reminders**, **Lens**, **Note**.
- Full-width **Save** (`FilledButton`); **Delete** in `error` red — *the one sanctioned
  alarm-red use*.

### 3.5 Recurrence editor → `examples/ui/06-recurrence.html`
- Segmented frequency **Off · Day · Week · Month · Year** (Off = one-off).
- **Every-N** stepper; Week → weekday chips; Month → day-of-month + "Last day"; Year →
  month + day; the **Starts** (anchor) row.
- **Live plain-English summary banner** (tangerine tint) at top, restated on every change.
- Ordinal-weekday ("2nd Tuesday") intentionally **out** for v1 (concept §11).

### 3.6 Pills & FAB
- Status pill = uppercase `labelSmall`, `full` radius, tinted fill (§1). NOW/ACTIVE
  tangerine · FOCUS indigo · due amber.
- **FAB pair** (the knabberfuchs pattern): the Fuchsbau extended full-pill `+ Add`
  (create task/habit — THE action, one tap), with a **small secondary FAB** beside it
  opening a bottom sheet of structure actions (new view · new lens here; later the
  current View's dial-editing). Bottom-right, tangerine, unique `heroTag` per screen.
