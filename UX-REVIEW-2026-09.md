# UX review — September 2026

Three reviewers each read one third of `screenshots/flows/` (31 shots from
`integration_test/flows_test.dart`, build 1.0.0 as of 2026-09-15) against
`DESIGN_SYSTEM.md`: onboarding + create, detail + stats, settings + library.
Every claim below that touches code has been checked against the source; the
verdict column says which held up.

Their shared conclusion: the model is sound and the house style is finished,
but the screens narrate the model instead of teaching it, and two genuine
defects (the invisible FAB, reminders that cannot fire) are worse than any
of the wording problems.

---

## 1. Confirmed defects — code-verified, fix these first

### 1.1 The primary FAB has no contrast (blocker)
`lib/../fuchsbau/lib/src/theme.dart:153` sets only `shape` on
`FloatingActionButtonThemeData`, so the FAB falls back to Material's default
`primaryContainer` — which this palette defines as orange mixed 16 % into the
card colour (`theme.dart:73`). Measured 1.09:1 in light and 1.49:1 in dark
against the page; 3:1 is the floor for a control boundary. The button is
readable only by its label and shadow, and the small structure FAB beside it
has no visible body at all. The comment directly above the theme block says
the family default is `primary`, so the intent is already written down and
not implemented.
*Fix:* `backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary`
in the shared theme, the same tangerine the Save button already uses.

### 1.2 Reminders offered that can never fire (major)
`ReminderPresetChips` (`lib/ui/reminder_presets.dart:41`) renders all three
presets unconditionally. On a to-do with no due date, "2 hours before due"
and "When it's due" tick on, look saved, and resolve to a null fire time.
Two reviewers found this independently (`12_create_todo_reminder`,
`18_detail_todo`).
*Fix:* disable both when the task has no end edge, and make a tap on the
disabled chip open the Due picker.

### 1.3 "1 days · best 1" (major, hits all four locales)
`statsStreakDays` is `"days · best {best}"` with the count rendered
separately (`lib/ui/stats_screen.dart:516`), so the unit is never
pluralised. `dayStreak` next door already does this correctly.
*Fix:* one ICU plural string carrying both numbers.

### 1.4 The lens editor is two different screens (major)
`lib/ui/view_edit_screen.dart:213` gates the membership card on
`viewId == null`. Opened from Settings → All lenses it can edit which tasks
are in the lens; opened from inside a view that card is absent, with nothing
saying so. The card is also titled "All tasks", the same words as the global
inventory one level up in Settings.
*Fix:* show it in both paths, retitle it "Tasks in this lens" with the member
count, and title the screen with the lens name.

### 1.5 "All tasks" groups on two incompatible axes (major)
`_TaskSections(splitKinds: true)` emits To-dos, Habits, then Upcoming, then
Resolved. Type and time state are peers, so a habit whose window has not
opened sits under Upcoming and not under Habits. The one screen that should
answer "where does this thing live" cannot be trusted to list it.
*Fix:* group by type only and let the existing pills carry state, or make the
time cut a filter row rather than a third section.

### 1.6 No "New view" anywhere in the library (minor)
`AllLensesScreen` has a New lens button; `AllViewsScreen` has none, so
creating a view is only possible from the home FAB sheet. The reverse gap
exists too: a view's editor cannot add an existing lens, only the lens's own
"Shown in" checkboxes can.
*Fix:* a New view button on All views, and an "Add a lens" row in the view
editor.

---

## 2. Design critiques worth acting on — judgment, not defects

### 2.1 The detail sheet never shows or sets the current state (major)
It carries identity, streak, navigation rows, reminders and two deletes, but
not "today: open until midnight", and it has no Done or Skip action. The
most common reason to open a task is answered only by walking into History.
The reviewer's proposal, which I would take: a status line and Done/Skip
directly under the name, everything below it as configuration.

### 2.2 Two save models on one sheet (major)
Toggles, reminders, lens, window and repeat commit instantly; name and note
wait for Save. A rename followed by a swipe-dismiss is lost silently. Going
all-instant (commit name and note on blur and on dismiss, drop the button)
is the smaller, more honest change.

### 2.3 The two-row active window does not read as two questions (major)
"How long" and "Which hours" are the lowest-contrast text in the block,
their chips are visually identical, and single-select and multi-select look
the same. The summary sentence, which carries the whole explanation, is set
in muted grey and uses "Open" twice with two meanings, plus "12:00 PM" and
"12:00 AM" in one line. Note that "6:00 PM–12:00 AM" also breaks our own
rule that a midnight end reads as its evening.
*Suggested:* bound each question in its own block, put the times on the
preset chips, promote the summary to the tinted-banner treatment already
used by Repeat, and rewrite it in the user's words.

### 2.4 The create sheet asks too much before the first Save (major)
From "Start clean" a first-run user meets a type toggle, name, note, lens
chips, a repeat banner, a four-way segmented control, a stepper, a start
date and ten window chips, with Save below the fold. Everything except the
name has a sane default.
*Suggested:* name plus Save, with the rest behind a "More options"
disclosure that remembers being opened; land on an empty Home first rather
than opening the sheet over an app the user has not seen.

### 2.5 Lens dial vocabulary (major)
"Continuous — refills right away" describes a mechanism that is not running
when "Tasks shown" is All; "Automatic" carries no meaning without its
parenthetical; two further dials appear only under conditions the user
cannot see. Plain-language rewrites proposed: "Order: Oldest first",
"Refresh: whenever there's room" versus "Refresh: every Monday", "Which
ones: the first in order / a random few", "Rest a task after 2 unworked
weeks", and hide Refresh entirely while nothing is limited.

### 2.6 Colour carries meaning alone in several places (major)
Avoidance amber versus active orange are one glyph and two close hues, with
no word anywhere; "TOMORROW" appears grey on a habit (window opens) and
amber on a to-do (due) on the same screen. In the stats week grid, Open and
No window differ only in hue and stroke at 28 px. Unselected chips in dark
mode measure 1.09:1 against the sheet, so they read as captions rather than
controls.
*Suggested:* prefix pills with their verb, give avoidance a mark rather than
a shade, and give unselected chips a real outline in both themes.

### 2.7 Duplicate-looking rows and contradictory counts (major)
In the Habits view the same habit name appears twice in one card, once as
today's slot and once as a past outcome, under a header reading "DAILY
HABITS · OUTCOMES". A "THIS WEEK" card says "1 left" above a single
completed row. "19 tasks" on a lens sits one tap from "2 done · 4 left" for
the same lens, with no explanation that one counts members and the other
counts instances.

### 2.8 Smaller items worth a pass
Intro page three describes the three demo views, which do not exist if you
choose Start clean. The to-do variant defaults its lens to "Daily habits".
Reorder handles sit in the right-edge back-gesture strip, under 48 dp, next
to the chevron. Section headers and the reorder hint measure 3.5:1 where
4.5:1 is required. Chips and steppers are roughly 31–36 dp tall. The
structure sheet has no title, against our own sheet rule. "Edit this view"
is the title even when you picked the view from a list. Vacation's empty
state scatters explanation, message and action across three zones. The app
bar says "Checkfuchs" on all three views, which the bottom bar already
labels.

---

## 3. Rejected, or already decided

- **"Restore Off to the repeat editor."** Deliberately removed on 2026-09-13:
  the Habit/To-do toggle owns that choice now, and habit → to-do is
  confirmed by a dialog that names the cost. One reviewer missed the dialog
  and called the toggle unguarded; it is guarded in that direction. To-do →
  habit is unguarded, which is fine, since it is reversible.
- **"Bind the Also-show chips to the view↔lens pair."** The opposite was
  decided on purpose in schema v12: "Also show" is a property of the lens,
  and `view_lens.status_filter` is dead legacy. `DESIGN_SYSTEM.md:95` still
  claims per-pair behaviour and should be corrected — the doc is the thing
  that is wrong here, not the code. The reviewer's observation that a second
  lens exists in the demo data purely to vary outcomes is fair, and is an
  argument about the demo data, not the model.
- **"Save is unreachable in the create sheet" (claimed blocker).** Capture
  artifact. Save is the last child of a scrolling sheet and is plainly
  visible in `09_create_habit_window.png`. The harness unfocuses the
  keyboard and screenshots while the sheet is still resizing, which crops
  `04`, `08` and `11` mid-widget.
- **"The stats card is clipped by the navigation bar."** Also a capture
  artifact: the list already adds the bottom inset
  (`lib/ui/stats_screen.dart:87`), and the shot was simply taken mid-scroll.

---

## 4. What the reviewers agreed works

- The pill vocabulary: pending rows say when the window opens, active rows
  say when it is due, anytime rows stay bare.
- Missed is taupe and struck, never red; the destruction-only red rule holds
  in both themes.
- The stats completion card shows its arithmetic ("11 done · 0 skipped ·
  4 missed of 15 windows") instead of asking for trust, with the legend sat
  directly under the marks it explains.
- The delete confirmations say exactly what survives, which is the single
  most reassuring copy in the app.
- "Shown in" as checkboxes on the lens is the right model choice, and makes
  moving a lens legible without inventing a gesture.
- The property-row pattern in the detail sheet, and the fact that the sheet
  genuinely reshapes between habit and to-do rather than showing dead rows.
- The tile chooser is the best-written screen in the set: every row explains
  what it shows rather than restating its own title.
