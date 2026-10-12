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
| Counter (below min) | **segmented ring** — one arc per check-in slot, filled ones solid | orange |
| Counter (met) | segmented ring; past a no-limit minimum, the full ring carries the count | emerald |
| Counter (at max) | `check_circle` (filled) — the ordinary Done | emerald |

The segmented ring (`GoalRing`, `lib/ui/goal_ring.dart`, mockup
`examples/ui/10-counter.html`) is the one marker that isn't a Material Symbol: it has to
show *how far* a cycle got. Slots = `max` (or `min` with no limit); more than 12 read as
a smooth arc. A 1-of-1 habit never wears it.

## 3. Components (checkfuchs surfaces)

Base patterns (FAB, sheets, segmented edits) are Fuchsbau's; below is how checkfuchs's
screens use them.

### 3.1 Task row → `examples/ui/05-task-detail.html`
- Layout `[marker] name … [hint | pill]`, min height **56**.
- **Tap the marker ring = instant `Done`** (the 80 % action).
- **Swipe** reveals actions — continuous lens: **Done · Skip**; periodic lens: **Done ·
  Skip · Pass**. `Pass` = `arrow_forward` (indigo). **Never a destructive action on swipe.**
- `Missed` row: faded ring + struck taupe name.
- **Counter rows** (concept §3.7): the segmented ring, and the trailing slot shows
  progress instead of the deadline — "1 / 2" orange below min, "2 / 2–3" emerald once
  met, "9 · NO LIMIT" past a no-limit minimum. Tap the ring = **+1** check-in; the swipe
  reads **+1** and only offers what would act (no Skip once met). A *missed* counter's
  ring opens the detail sheet — a forgotten check-in needs a time. A met row stays in
  the list but counts as **done** in the lens header (it can no longer Miss).

### 3.2 Lens card → `examples/ui/04-lens-view.html`
- A `lg`(20) card. Header = lens name + the **text-breakdown summary**
  ("1 done · 1 missed · 2 open · 5 upcoming", `missed` in taupe, `upcoming` faded —
  context, not work — zero parts omitted). **open** = actionable now (active or
  overdue), **upcoming** = window not open yet — the same words as the drill-in's
  sections; never a lumped "left". Each lens chooses its parts (*Summary shows*:
  Done — with missed — · Open · Upcoming, all on by default). Header counts
  and the `statusFilter` rows cover the lens's **current outcomes only** — a terminal
  instance is shown while it is its habit's latest non-future slot (a completed daily
  shows ✓ until tomorrow's slot arrives, a weekly all week; resolved one-offs for the
  rest of the day). Never a history list — history lives in analytics. (The Habitify
  shape: today's check stays in place at the bottom of the card, yesterday's is gone.)
- The header counts everything, so when the `statusFilter` hides outcome rows the
  breakdown becomes a **tap-to-peek** (chevron affordance): expanding appends the hidden
  current-outcome rows below the list, collapsing removes them. Transient — the
  persisted filter never changes.
- Periodic lens: focus row uses the Focus marker + `FOCUS` pill; quota-met → "done this week".
- An **empty lens still renders its card** — header plus "Nothing to do. Well done 🦊"
  in muted outline. A cleared list is an earned state, not a disappearance.

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
- `statusFilter` ("Also show": done / skipped / missed / upcoming) belongs to the
  **lens**, not to the View↔Lens pair (schema v12 — one lens, one reading, edited in
  one place). `view_lens.status_filter` is dead legacy; the pair still carries its
  `sortOrder` (the card order within a View).

### 3.4 Detail sheet → `examples/ui/05-task-detail.html`
- Bottom sheet (Fuchsbau pattern): `xl`(28) top, drag handle, `isScrollControlled`.
- **A close ✕ at the top right** (beside the kind toggle; beside the title on the
  create sheet). These sheets fill the screen, so swiping the handle isn't a
  discoverable way out. On the detail sheet closing saves, like every exit.
- Order, matching the create sheet: **kind toggle → name + note → status block →
  stats/history → lenses → scheduling → reminders → delete**.
- The **status block** is the sheet's first answer: one line saying what state the
  current instance is in ("Open until 18:00", "Done 19:12", "Missed — the window
  closed") and the actions that change it (Done · Skip, Mark done anyway, Reopen).
- **Everything on the sheet saves itself.** No Save button: rows commit on change,
  the text fields commit on blur and again when the sheet closes. A sheet that mixes
  instant rows with a Save button loses edits on a swipe-down.
- Prominent name field; **This-occurrence / The-series** segmented (only when recurring).
- Property rows (icon + label + value, drill-in): **Active window** (day/morning/…/time
  chips), **Repeat**, **Reminders**, **Lens**, **Note**.
- Full-width **Save** (`FilledButton`); **Delete** in `error` red. Error red is
  reserved for **destructive actions** (delete task/series, delete view/lens,
  delete a vacation, Delete all data, the developer reset) — each behind a
  Cancel → Confirm dialog — and never for task state (a Miss is taupe).

### 3.5 Recurrence editor → `examples/ui/06-recurrence.html`
- Segmented frequency **Off · Day · Week · Month · Year** (Off = one-off).
- **Every-N** stepper; Week → weekday chips; Month → day-of-month + "Last day"; Year →
  month + day; the **Starts** (anchor) row.
- **Live plain-English summary banner** (tangerine tint) at top, restated on every change.
- Ordinal-weekday ("2nd Tuesday") intentionally **out** for v1 (concept §11).
- An **Ends** row under Starts (optional end date; "Never" until picked, ✕ clears).

### 3.5a Times section (goal) → `examples/ui/10-counter.html`
- Sits between **Repeat** and **Active window** on the create sheet; a **Times** row in
  the detail sheet's series rows opens the same editor as a sheet.
- **Progressive disclosure** — collapsed to *one* stepper by default (a fixed goal,
  at least = at most; at 1 it's an ordinary habit and the banner stays silent). A
  **Range…** chip splits it into **At least / At most** + **No limit**; tapping
  **Range** again folds it back (at most snaps to at least). The chips sit on their own
  line under the steppers, so long translations never squeeze them.
- **Once a day** appears only when the goal is above 1 *and* the window spans more than
  a day; **Remind until** (Minimum · Maximum) only in range mode, where the ends differ.
- The repeat banner echoes the goal: "Every week, 2–3 times, once a day".
- Detail sheet: the status line leads with progress ("1 of 2–3 · Open until Sunday"),
  the primary button reads **Check in**, and a **Check-ins** list shows the cycle's
  check-ins (✕ removes) with **Add a forgotten check-in** (day, then time, clamped into
  the window).

### 3.6 Pills & FAB
- Status pill = uppercase `labelSmall`, `full` radius, tinted fill (§1). NOW/ACTIVE
  tangerine · FOCUS indigo · due amber.
- Tile pills are **informative, never vague**: pending rows show *when the window
  opens* in muted grey ("18:00" · "TOMORROW" · "SAT" · "12 JUL"), active rows with a
  deadline show *when it's due* in amber (same scale). Anytime tasks carry no pill.
  An end at midnight reads as its evening's day ("TODAY"), never "00:00".
- **FAB pair** (the knabberfuchs pattern): the Fuchsbau extended full-pill `+ Add`
  (create task/habit — THE action, one tap), with a **small secondary FAB** beside it
  opening a bottom sheet of structure actions (new view · new lens here; later the
  current View's dial-editing). Bottom-right, tangerine, unique `heroTag` per screen.
