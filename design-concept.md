# Checkfuchs — Conceptual Design

> **Status:** Canonical conceptual specification (rebuilt from first principles).
> This fixes the *data model*, *object responsibilities*, *state machines*, and
> *edit semantics*. Tech stack, design system, and screen layout are defined
> separately. Anything labelled **(visualization)** or **(deferred)** is explicitly
> out of scope here.
>
> This document supersedes the original draft (preserved in git history). The biggest
> change: **status lives *only* on the Task**, and the old "Pool" is now a pure
> presentation layer renamed **Lens**.

---

## 1. Problem & Philosophy

### 1.1 The core problem
Existing tools split **habits** (recurring behaviours, no due date) from **to-dos**
(dated tasks). For the target user these are **one mental object** with different time
horizons, not two systems. Pure to-do apps get adopted then dropped, because on a full
day nothing gets ticked → no reason to open the app → it goes unseen → it dies.

### 1.2 The carrier mechanism
A **daily habit** (brushing teeth) is unavoidable and so guarantees the app is opened
every day. That daily open is the carrier that keeps everything else visible. Habits
and to-dos share one surface; while checking off the unavoidable daily habit, the user's
eye passes the important dated items.

### 1.3 Anti-rigidity (the central value)
The target user has a documented drop-reflex with rigid systems. Therefore:

- **"Not done" is data, never punishment.** A missed habit is *tracked*, not *failed*.
- The simple case (one daily habit) must show **zero complexity**. Power is summoned,
  never imposed.
- **The app must never act behind your back.** This is a hard correctness value, not a
  nicety — it shapes the generation, edit, and reminder rules throughout.

### 1.4 The separation law (the spine of the whole model)
Every hole in the original draft came from one object reaching into another's job. The
rule that fixes it:

| Object | The single question it answers | Owns status? |
|---|---|---|
| **Template** | *When is a Task born, and with what defaults?* (generation) | No |
| **Task** | *What is the state of this one thing right now?* (lifecycle) | **Yes — the only one** |
| **Lens** | *Which Tasks do I see, in what order?* (selection) | **No** |
| **View** | *Which Lenses do I see, arranged & filtered?* (the screen) | **No** |

> **If a property changes what a Task *is*, or *when it regenerates*, it belongs on the
> Task or the Template — never on a Lens or View.** Presentation only ever changes what is
> *shown*. The four layers nest: **Template → Task → Lens → View** (§4.6).

There is also one **app-level** concept that belongs to none of these: **Vacation**
(§6).

---

## 2. Task — the only completable object

A Task is one concrete to-do/habit instance. It is the **only** object with a completion
status, and the **only** source of analytics.

### 2.1 Fields
| Field | Type | Meaning |
|---|---|---|
| `name` | string | the label |
| `note` | string? | optional free text (also the informal multi-item escape hatch) |
| `status` | enum | `Open · Done · Skipped · Missed` (see §2.2) |
| `start` | datetime? | when it becomes **Active**; absent ⇒ active immediately |
| `end` | datetime? | when the window closes; absent ⇒ **endless & unfailable** |
| `notifications` | list | local pings (see §2.4) |
| `templateId` | id? | the Template that generated it; **null = standalone one-off** |
| *(membership)* | join | Lens membership lives on the `Task↔Lens` join (§4), not here |
| `createdAt` | datetime | when the instance came into being |
| `resolvedAt` | datetime? | when it went terminal; null while Open — **required for analytics** |
| `goal` | `{min, max?, oncePerDay, remindTill}` | stamped from the Template (§3.7); `1 of 1` for every other Task |
| `checkIns` | datetime[] | the check-ins toward the goal (§3.7); for a 1-of-1 Task, its single Done |

*(Deferred:* `checklist: [{label, status}]` *— additive, no per-item logic, no per-item
windows. Multiple windows ⇒ multiple Tasks. Not in v1.)*

### 2.2 Status — four live-or-terminal states
```
                    ┌──────────────────────────────► Done      (user · only while Active)
   ┌──────┐         │
   │ Open │ ────────┼──────────────────────────────► Skipped   (user · anytime while Open)
   └──────┘         │
   (live, no        └──────────────────────────────► Missed    (automatic · end passed)
    terminal
    decision yet)
```

- **`Open`** — the live state, *no terminal decision yet*. Whether an Open task is
  *Pending* or *Active* is **derived from the dates, never stored** (§2.3).
- **`Done`** — user completed it. Allowed **only while Active**.
- **`Skipped`** — user deliberately declined *this* instance. Allowed **anytime while
  Open** (Pending or Active). **Neutral** to progress (a guilt-free rest day).
- **`Missed`** — **automatic**: `end` passed while still Open. **Irrevocable failure** —
  the window is gone, like missing a birthday. There is **no hard/soft variant**: a Task
  knows nothing about its siblings, so a missed habit and a missed deadline are the same
  *fact*. Whether that fact *feels* like data or failure is read from the Template at
  render time **(visualization)** — see §2.6.

> **Principle:** `status` = *decisions that were made*; the dates = *where you are in
> time*. Two `Open` tasks can look completely different on screen (one greyed-pending,
> one live) with identical stored status.

### 2.3 Window & derived phases
Both dates are **datetimes** (so partial-day windows work — "brush teeth (morning)" must
fail by noon). The UI offers shorthands — *just a date* (00:00–23:59), *morning /
afternoon / evening*, *specific time* — that resolve to raw datetimes.

```
   now < start          start ≤ now ≤ end           end passes while Open
   ┌─────────┐  ──────►  ┌────────┐  ─────────────►  Missed (automatic)
   │ Pending │           │ Active │
   └─────────┘           └────────┘
```

- **`start` absent** ⇒ active immediately from creation.
- **`end` absent** ⇒ **endless & unfailable**: only `Done`/`Skipped`, never `Missed`.
  This is the *someday/backlog* case and produces no miss-data.

> **Invariant:** a Template-generated Task is **always bounded** (it always gets an
> `end`, the next occurrence at the latest) and so always failable. **The only deathless
> Tasks are the one-offs you typed in by hand.**

### 2.4 Notifications
A general array — the four trigger types are one mechanism wearing four hats:

```
notifications: [ { anchor: start | end | absolute, offset: Duration } ]
```
- *at start* → `(start, 0)` · *upcoming activation* → `(start, −1d)` · *due* → `(end, 0)`
  or `(end, −2h)` · *reminder* → `(absolute, <datetime>)`. The UI shows friendly presets.
- **Validation:** a `start`-anchored ping requires the Task to *have* a `start`; `end`
  likewise. `absolute` works regardless.
- **Lifecycle:** relative fire-times **recompute** when the window is edited, and **all
  pending pings cancel** the moment the Task goes terminal. (No pinging you about a task
  you already closed.)
- Defaults are inherited from the Template and stamped per instance.

### 2.5 Actions by phase
| Phase | `Skip` | `Done` | `Missed` |
|---|---|---|---|
| Pending (`now < start`) | ✓ (pre-empt a known conflict) | ✗ | — |
| Active (`start ≤ now ≤ end`) | ✓ | ✓ | — |
| window end passes while Open | — | — | ✓ automatic |

*Pre-empt example:* "Wash clothes, active Wednesdays — but I'm away this Wednesday"
→ `Skip` it while still Pending.

### 2.6 The two "feels" of a Missed — not stored
A missed floss (data) and a missed birthday gift (real failure) are the **same** Task
fact. The difference is *"will a successor exist?"* — a recurring Template spawns
tomorrow's instance (soft), a one-off has none (final). That judgment is **computed from
the Template at display time**, never a field on the Task. **(visualization)**

---

## 3. Template — the recurring factory

A Template defines **when** a new Task is born and **with what defaults**. It is **never
completed** and **carries no status**. There is **no one-off Template**: a standalone
to-do is just a `Task` with `templateId = null`.

### 3.1 Recurrence — a curated subset of the calendar standard (RRULE-shaped)
```
recurrence: {
  freq:       daily | weekly | monthly | yearly      // no "once"
  interval:   int                                    // "every N" (default 1)
  byWeekday:  [weekday]?                              // weekly: which day(s)
  byMonthDay: int?                                    // monthly: 25  (−1 = last day)
  byMonth:    int?                                    // yearly: 3 (March) + byMonthDay
  anchor:     date                                    // the reference intervals count from
  until:      date?                                   // last occurrence day (RRULE UNTIL); null = forever
}
```
| Want | Encodes as |
|---|---|
| every day | `freq: daily` |
| 25th of every month | `freq: monthly, byMonthDay: 25` |
| Saturday every two weeks | `freq: weekly, interval: 2, byWeekday: [Sat], anchor: <a Saturday>` |
| 13th of March | `freq: yearly, byMonth: 3, byMonthDay: 13` |

- The **`anchor`** is load-bearing for any `interval > 1` ("every two weeks" is meaningless
  without "from *when*").
- **`until`** bounds the *series*, not the window: "daily for the next 7 days" ends on day
  7, whose instance still runs its full window; nothing generates after it. Moving the end
  in drops an untouched instance past it; reviving an ended series sets the generation
  floor (§3.5) so the finished stretch is never back-filled as Missed.
- **Month-overflow clamps** to the last valid day (Feb has no 31st); `byMonthDay: -1`
  means "last day of the month."
- The same primitive also drives **Lens periods** (§4) — one calendar engine, two jobs.
- Exportable to real `.ics` later, but none of RRULE's scary corners are exposed.

### 3.2 Defaults it stamps onto each generated Task
`name`, `note`, `notifications`, **Lens membership(s) + default order**, and the **window
rule** (below). Editing these on the Template changes *future* instances only.

### 3.3 Window rule
How each instance's `start`/`end` are derived from its occurrence date:
- **Slice** — a named/timed band on the occurrence day (*morning* = 00:00–12:00, *evening*,
  or an explicit range). → "brush teeth (morning)".
- **Duration** — `start = occurrence`, `end = occurrence + duration`. → "active for the
  week before the birthday".
- **Default (unset)** — `start = occurrence`, `end = next occurrence`. → classic daily habit.

### 3.4 Generation — materialize the present, project the future
- The engine materializes **only the current open instance**.
- **Future occurrences are virtual** — computed on demand from the recurrence rule (like
  a calendar grid), never stored.
- **Acting on a virtual occurrence materializes it.** Pre-`Skip` next Wednesday → a real
  `Skipped` Task springs into existence for that date; everything untouched stays virtual.
- When the current instance goes terminal, the next occurrence becomes current and
  materializes.

> **Resolution rule:** for any occurrence slot, *a stored Task wins; otherwise show the
> virtual projection.* So the mere existence of a stored Task **is** the override. A
> Template edit never rewrites stored Tasks — it only fills empty (virtual) slots — so
> "edit all future occurrences" is free, individually-edited occurrences survive
> automatically, and **no `is_exception` flag is needed**. The currently-running instance
> is the only stored one and is left untouched (no surprise changes).

### 3.5 Pause
```
paused: bool   +   resumeOn: date?
```
- `false` → generating · `true + null` → suspended indefinitely (manual resume) ·
  `true + <date>` → auto-resumes on that date (planned vacation).
- While paused the engine generates **no new instances**; the *current* open instance is
  left alone (you can still do/skip it, or let it Miss). **Pause ≠ delete** — history is
  untouched.

### 3.6 "Turn into a series"
A one-off (`templateId = null`) becomes recurring by: pick a recurrence → create a
Template, copy the task's window/notification/lens settings into its defaults → set the
task's `templateId`. The engine takes over from the next occurrence.

### 3.7 Goal — counting habits ("gym 2–3× a week")
Not a third kind of thing: **every habit has a goal; an ordinary habit's is 1 of 1.** A
counter is a habit whose cycle wants *several* check-ins — gym twice or three times a
week, on whichever days, or water at least eight times a day. The cycle is the existing
recurrence + window, so end date, pause, vacation, reminders and lenses come for free.
Multiple weekly Templates can't express this: each pins a weekday ("Wed" Misses if you
went Thursday) and none can say "2 to 3".

```
goal: {
  min:        int ≥ 1          // check-ins that meet the cycle (default 1)
  max:        int? ≥ min       // the cap; null = no limit (default = min)
  oncePerDay: bool             // at most one check-in per calendar day (default false)
  remindTill: min | max        // when pending reminders stop (default min)
}
```
| Want | Encodes as |
|---|---|
| ordinary habit | `min 1, max 1` |
| gym 2–3× a week, never twice a day | weekly, window = the week, `min 2, max 3, oncePerDay` |
| brush teeth twice a day | daily, `min 2, max 2` |
| water, at least 8, log every glass | daily, `min 8, max null` |

**Stamped, like every default (§3.2).** Each generated Task carries its own copy of the
goal (all four fields — the reminder scheduler only ever sees Tasks), so a Task resolves
itself. A goal edit reaches the **running** instance too, like every series edit (§5),
and re-resolves it at once: raising `min` past the count un-meets it, lowering `max` to
the count makes it Done (extra check-ins stay on the record). Finished cycles keep the
goal they were judged by. Template-generated Tasks only — a counting one-off is
deferred (§11).

**Check-ins.** The Task records a list of check-in timestamps (`checkIns`, §2.1).
`count = checkIns.length`. A check-in is allowed while the Task is **Active** and
`count < max` (and, with `oncePerDay`, no check-in yet on that calendar day). Tapping the
ring — the 80 % action (DESIGN_SYSTEM §3.1) — adds one check-in at *now*.

**Status follows the count** — `met` is *derived*, never stored (like Pending/Active):

| Situation | Status | Shown as |
|---|---|---|
| `count < min` | Open | in the list, partial ring (1/2), can still Miss |
| `min ≤ count < max` (or no max) | Open, **met** | in the list, done colour, still takes +1, can no longer Miss |
| `count = max` | **Done** (`resolvedAt` = that check-in) | leaves the list like any finished habit |
| window ends while met | **Done** (automatic, `resolvedAt` = last check-in) | — |
| window ends below `min` | **Missed** | struck, with its count ("1 of 2") |

`min = max = 1` goes straight Open → Done on the first check-in: today's behaviour,
unchanged. *No limit* means the met Task stays in the list, taking +1s, until its window
closes. This softens §2.2 in one place: a met counter is the one **automatic Done**.

**Corrections (detail sheet).** The check-ins are listed and each can be removed; a
forgotten one can be added with a past time **inside the window** (same rule as §11 q7 —
a logging fix on a habit). Every change re-resolves the Task: removing one below `max`
reopens a Done (if the window is still open), or turns an expired Done into Missed when
it drops below `min`; adding one to a Missed Task can make it Done.

**Skip** is allowed while Open and **below `min`** (a met cycle can't fail, so there is
nothing to decline). The check-ins already made stay on the record. On vacation (§6)
the auto-Skip applies only below `min`; a met instance resolves Done instead.

**Reminders** (§2.4) follow `remindTill`: with `min` (the default) pending pings cancel
once the Task is **met** — the reminder's job, don't Miss, is done; with `max` they keep
firing until the Task reaches its cap and goes Done. With no limit and `max`, they run
until the window closes. The choice only shows when `max ≠ min` — for a fixed goal both
mean the same moment.

**Validation (§7).** `max ≥ min`. `oncePerDay` only makes sense when the window spans more
than one day, and needs `min ≤` the days in the window — "3× a day, once a day" and "5×
in a weekend, once a day" are rejected at configuration time.

---

## 4. Lens — pure presentation

A **Lens** is a way of *looking* at Tasks; it neither holds nor owns them. **It never
reads or writes status — it only changes what is *shown*.** (Formerly "Pool".)

### 4.1 Fields
| Field | Values | Meaning |
|---|---|---|
| `name` | string | user-defined |
| `showCount` | `1 \| 2 \| 3 \| … \| all` | how many slots are surfaced |
| `ordering` | `dueDate \| manual \| automatic` | how members are ranked (manual = priority, automatic = FIFO) |
| `selection` | `top \| random` | how the shown set is drawn (top = first `showCount` by order; random ignores order) |
| `period` | `none \|` calendar cadence | refill behaviour (§4.3); reuses the §3.1 primitive (so a 17-day lens is fine) |
| `dormantAfter` | `N` | periods unworked before a task goes **Dormant** (periodic lenses only) |

### 4.2 Membership & per-pair state
- Membership = a **`Task↔Lens` join** (many-to-many: a Task can appear in several Lenses,
  e.g. weekly habits also shown in a daily overview).
- The join row carries the **per-pair** state: `order`, `surfacedAt`, `passedThisPeriod`
  (Dormancy is *derived* from `surfacedAt` + the lens period, not a stored counter).
- **Templates** stamp a default Lens + order onto each instance they generate; **one-offs**
  set the row directly.
- **Order persistence:** reordering a *recurring* member writes back to the **Template's
  default order** (a series-level edit, so it sticks for tomorrow). `dormancyCounter` /
  `passedThisPeriod` are per-instance and **reset each cycle**.

### 4.3 `period` decides refill behaviour
- **`none` → continuous:** a freed slot (on `Done`) **refills immediately** with the next
  task. Dormancy does not apply. *(daily habits, due-date lens)*
- **periodic (week / month / any cadence) → hold-till-rollover:** completing meets your
  quota for the period; the slot shows "nicely done" and **holds** until the next
  rollover. Over time you work down the list. Dormancy applies. *(week/month work-down
  lenses)*

### 4.4 The three load-bearing verbs (the old "skip" confusion, resolved)
| Word | What it is | Touches status? |
|---|---|---|
| **Skip** | decline the **Task** → terminal `Skipped` | **Yes** |
| **Pass** | "not this one this period — show another"; Task untouched, stays a member | No (display) |
| **Dormant** | a shown task sits `N` periods unworked → sinks out of view, stays a member, **resurfaces later** | No (display) |

Only **Skip** is a status change. **Pass** and **Dormant** rearrange the furniture; the
Task is serenely unaware.

### 4.5 The three tiers dissolve
The original "Forced / Self-announcing / Passive" tiers and a special **"Today"** surface
are **not** data concepts — they are points on the dials above:
- *Forced* = a continuous "everything" Lens you keep in front of you.
- *Self-announcing* = a due-date Lens with a small `showCount`.
- *Passive* = a periodic work-down Lens you visit.

There is **no special "Today" object.** "Today" is simply a **View** (§4.6) you open.

### 4.6 View — the screen layer (arranging Lenses)
A **View** is a user-composed screen: an ordered set of **Lens references**, and the
**top-level navigation** of the app (Home, Habits, Short Term, Long Term — all
user-defined). It is the top of the presentation stack and, like the Lens, **never
touches status**.

`View ↔ Lens` is a membership join (mirroring `Task↔Lens`, §4.2) carrying the per-pair
display state:
- `order` — where the Lens sits in this View.
- `statusFilter` — which **terminal** states (`Done` / `Skipped` / `Missed`) to surface
  *alongside* the always-shown open tasks. **Default: open-only** (calm, actionable). A
  *tracking* View (e.g. "Habits") opts `Done`/`Missed` back in to show the full day.

The same Lens may appear in several Views with **different** filters — *Home* shows the
Habits lens open-only (quick glance); *Habits* shows it in full (progress + misses). This
is why `statusFilter` lives on the join, not on the Lens. "Today" is not special; it's
just the View opened first.

> A View can become overwhelming if it holds every Lens — so the user builds *focused*
> Views (a calm Home, a detailed Habits, a Long-Term backlog) instead of one firehose.

---

## 5. Edit semantics

- **Edit this instance** — change the materialized Task directly. Because a stored Task
  wins over the projection (§3.4), the edit survives future Template edits automatically.
- **Edit the series** — change the Template. Future instances follow it, and so does the
  **running** (open) instance: a new note, reminders, window hours or goal should not wait
  a cycle to take effect ("morning → evening" moves today's row). Its occurrence day and
  status history stay. **Terminal instances are history and are never rewritten** — the
  one exception is a rename, which reaches every instance (a habit is one thing across
  its history). Virtual future occurrences simply recompute against the new definition.
- No `is_exception` flag — *existence of a stored Task for a slot is itself the override.*

---

## 6. Vacation (app-level)

Belongs to none of the three objects — it is global state in settings.

- A **list of `{ start, end }` periods**, schedulable in advance (line up July's trip and
  September's now). `vacationActive(now) = now ∈ any period`.
- **Generation gate:** the engine emits a new instance only if
  `NOT template.paused AND NOT vacationActive`.
- **Treadmill only — not reality.** Recurring generation pauses, but a **hard-dated
  one-off still goes `Missed`** if its date passes while you're away. Silencing chores is
  honest; silently rescuing a real deadline would be the app lying.
- *(deferred detail:* when vacation *starts*, an already-open recurring instance is
  auto-`Skip`ped — leaning — vs left to Miss. Pin during engine implementation.)*

---

## 7. Constraints & validation

Validate at configuration time, not silently at runtime:
- A `start`-anchored notification requires a `start`; an `end`-anchored one requires an
  `end` (§2.4).
- `ordering = dueDate` is only meaningful for members that *have* a due date.
- General rule: **policy X requires field Y** — reject combinations that can't satisfy
  their own condition.

---

## 8. Evaluation / tracking

- **All analytics read from Task records only** — the stream of `Done` / `Skipped` /
  `Missed` outcomes plus their `resolvedAt` timestamps. Templates and Lenses hold no
  history.
- **Progress framing (anti-rigid):** lead with *completion rate over a window*, not a
  fragile streak. A deliberate `Skip` is **neutral** (rest day, preserves the run); an
  automatic `Missed` breaks the run but is shown as **neutral data, not red**.
- **Avoidance surfacing:** beyond a threshold of consecutive misses, render the item
  *differently* (e.g. colour) as **information, not a command**. **(visualization)**
- **Counters (§3.7) count in check-ins, not cycles.** Every check-in is one *done*; every
  check-in short of `min` when the cycle closes is one *missed* — gym at 1 of 2 is 1 done +
  1 missed, at 0 of 2 it is 2 missed, at 3 of 2–3 it is 3 done. Completion rate is
  `done / (done + missed)` over those units. The Task still holds one status; the missed
  units are derived (`min − count`), never stored.
- **Streaks** count consecutive **met cycles** ("3 weeks in a row"); a Skipped cycle is
  neutral, as everywhere. Day-level views (heatmap, week strip) place each check-in on its
  own day, so the gym days show where they happened.

---

## 9. Reminders (behavioural requirement)

- All reminder timings are **locally derivable** from a Task's `notifications` + window.
  No remote trigger is required — the device always knows when to fire (local-first,
  privacy-respecting).
- Reminders are **rescheduled on every state change** (complete, skip, reorder, new
  generation, window edit) — a hard correctness requirement (§2.4 lifecycle).

---

## 10. Glossary

| Term | Definition |
|---|---|
| **Task** | The only completable instance; the only object with a status and the only analytics source. |
| **Template** | Recurring factory. Generates Tasks lazily. Never completed. (One-offs are template-less.) |
| **Lens** | Pure presentation; selects/orders Tasks via a `Task↔Lens` membership. (Was "Pool".) |
| **View** | User-composed screen; arranges Lenses via a `View↔Lens` membership + `statusFilter`. Top-level nav. |
| **statusFilter** | Per `(View, Lens)`: which terminal states (Done/Skipped/Missed) to show beside open tasks. Default open-only. |
| **Open** | Live status, no terminal decision yet. *Pending* vs *Active* is derived from the dates. |
| **Pending / Active** | Derived phases of an `Open` task (`now<start` / `start≤now≤end`). Not stored. |
| **Done / Skipped / Missed** | Terminal statuses: user-completed / user-declined (neutral) / window-expired (automatic, irrevocable). |
| **Skip** | Status action: decline the Task (`→ Skipped`). |
| **Pass** | Lens display action: skip this period's *focus*, Task untouched. |
| **Dormant** | Lens auto-behaviour: a task unworked `N` periods sinks out of view but stays a member. |
| **Window** | `start`/`end` datetimes; absent `end` ⇒ endless & unfailable. |
| **Recurrence** | Template rule for when a new Task is generated (RRULE-shaped subset). |
| **Period** | A Lens's refill cadence (`none` = continuous; otherwise a calendar cadence). |
| **Vacation** | App-level list of `{start,end}` periods that gates generation (treadmill only). |
| **Goal** | A habit's check-ins per cycle: `min`, optional `max`, `oncePerDay`, and `remindTill` (min/max). Ordinary habits are 1 of 1. |
| **Check-in** | One timestamped tick toward a goal. A Task with enough is **met**; at `max` it is Done. |
| **Met** | Derived: an Open counter whose check-ins reached `min` — can no longer Miss, still takes +1. |

---

## 11. Open questions (deferred, not blocking)

1. Periodic-lens freed-slot fill when `selection = top` vs `random` — default TBD.
2. `showCount` configurable range per Lens.
3. Vacation-start handling of the already-open instance: auto-`Skip` (leaning) vs leave.
4. Snooze-until-date for a temporarily-blocked top item — v2 candidate.
5. Smart/filter Lenses (auto-membership by query) as a convenience layer atop explicit
   membership — later.
6. Checklists on a Task (array of `{label, status}`) — additive, if it ever earns its place.
7. **Retroactive logging / un-Miss.** "I brushed my teeth this morning but forgot to log
   it; this evening it's auto-`Missed`." This tensions with the locked "`Missed` is
   irrevocable" rule. Likely resolution: **recurring/habit** instances allow a past
   `Missed → Done` correction (it's a *logging* fix, not doing it late), while a true hard
   deadline stays irrevocable. Resolve during the engine stage; may soften §2.2 for the
   recurring case.
8. **Ordinal-weekday recurrence** ("2nd Tuesday", "last Friday of the month") — RRULE's
   `BYSETPOS`, intentionally excluded from v1 to keep the recurrence editor lean. Adding it
   later means one extra field on the recurrence struct + a mode in the Monthly editor.
9. **Counting one-offs** ("read 3 chapters by Friday") — the §3.7 goal on a template-less
   Task. The model allows it (the goal is stamped per Task); deferred until a habit
   counter has proven itself.
