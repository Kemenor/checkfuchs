# Habit & To-Do App — Conceptual Design

> **Status:** Conceptual specification. No tech stack, no design system, no UI layout.
> Those are defined separately. This document fixes the *data model*, *object
> responsibilities*, *state machines*, and *edit semantics* only.

---

## 1. Problem & Philosophy

### 1.1 The core problem
Existing tools force a split between **habits** (Habitify: recurring behaviours, no
real due date) and **to-dos** (Vikunja/Todoist: dated tasks). For the target user,
these are **one mental object** with different time horizons, not two systems. Every
standalone to-do app gets adopted and then dropped, because:

- On a full day, no to-do gets done → no reason to open the app → the app goes
  unseen → it dies.
- Pure to-do apps have **no anchor** that forces a daily open.

### 1.2 The carrier mechanism
A **daily habit** (e.g. brushing teeth) is unavoidable and therefore guarantees the
app is opened every day. That daily open is the carrier that keeps everything else
visible. The design exploits this:

- **Habits and to-dos share one surface.** While checking off the unavoidable daily
  habit, the user's eye necessarily passes the important dated items.
- As long as at least one daily habit exists, the app is opened daily, and nothing
  silently disappears.

### 1.3 Anti-rigidity (critical design value)
The target user has a documented drop-reflex with rigid systems. Therefore:

- **"Not done" is data, never a command or punishment.** A missed habit is tracked,
  not failed. The only genuine failure is a *hard date* that physically passes.
- **Avoidance and lack-of-capacity look identical in a single moment.** The system
  must not guess. Instead it surfaces *patterns over time* (e.g. "skipped 6 weeks in
  a row") as **information, not enforcement** — e.g. a colour change, never a forced
  action.
- The simple case must show zero complexity. Power is available when summoned, never
  imposed.

### 1.4 Three visibility tiers
| Tier | Behaviour | Example |
|------|-----------|---------|
| **Forced** | Always shown on the daily surface | Daily habits (teeth) |
| **Self-announcing** | Surfaces itself only near its relevant day | Hard-dated items |
| **Passive** | User visits on their own initiative; not forced into view | Pool backlog |

Passive items do **not** need to be a forced glance. Because the app *is* opened daily
(via habits), the user stays mentally aware that the backlog exists — this is the
opposite of "out of sight, out of mind." Only the **hard-dated** subset gets an active
push into the daily surface, and because hard dates are rare, this never creates noise.

---

## 2. The Three Objects

The entire model is three objects with strictly separated responsibilities.

| Object | Responsibility | Completable? | User-facing name |
|--------|----------------|--------------|------------------|
| **Template** | Recurrence definition / factory. Generates Tasks. | No | "Series" (hidden for one-offs) |
| **Task** | The actual to-do instance. The only thing checked off. | **Yes** | "Task" |
| **Pool** | Visibility & organization layer. | No | "Pool" |

> **Naming note:** The user only ever sees **Task** (the completable item) and
> **Pool**. **Template** is exposed only when relevant (editing a series), mirroring
> the Outlook *meeting series vs. single meeting* model — both individually editable.

---

## 3. Task (the completable instance)

A Task is one concrete to-do. It is the **only** object with a completion status, and
the only thing analytics read from.

### 3.1 Fields
- `completion_status`: `ToDo` → `Done` | `Skipped` | `NotDone`
- `active_window`: `{ start, end }` — when the task can be acted on
- `template_id`: nullable — the Template that generated it (null = standalone one-off
  with no exposed series)
- `is_exception`: boolean — has this instance been individually edited away from its
  Template? (see §5.3)
- `hard_due_date`: nullable — if set, grants **rotation immunity** (see §6.4)
- `missed_behavior`: `flag` | `archive` — what happens when a hard due date passes
  (per-task; see §3.4)

### 3.2 Lifecycle state machine
```
                 now ≥ start
   ┌─────────┐  ───────────────►  ┌────────┐
   │ Pending │                    │ Active │
   └─────────┘                    └───┬────┘
   now < start                        │
   (exists, not yet actionable)       │
                                      │
         user Complete ───────────────┼──────────────► Done
         user Skip ────────────────────┼─────────────► Skipped
         now > end while still ToDo ───┘  (automatic) ► NotDone
```

- **Pending** — created but `now < active_window.start`. Visible-but-not-actionable
  (e.g. a one-off you may only do 14–25 July, created in advance).
- **Active** — within the window and still `ToDo`. This is what "active" means: there
  is an open, actionable task. Actions are only permitted while Active.
- **Done / Skipped / NotDone** — terminal for this instance.

### 3.3 The two-axis coupling (subtle but central)
`completion_status` and *activity* are conceptually **orthogonal** — a Task can be
`ToDo` yet not-yet-active (Pending). But their **transitions are coupled**:

> When a Task leaves the active state while still `ToDo` (its window expires), it
> **must** be auto-recorded as `NotDone`.

This coupling is the mechanism that **generates the tracking data**. A daily habit
whose one-day window expires each evening auto-writes a `NotDone` record — that is
exactly how the habit history/streak is built. Without this rule there is no analytics.

User actions vs. automatic outcomes:
- `Done`, `Skipped` = **user actions**
- `NotDone` = **automatic** (window timeout)

### 3.4 Missed behaviour (hard dates only)
When a Task carries a `hard_due_date` and that date passes without completion, the
outcome is **terminal failure** — the task can no longer be completed. Per-task choice:
- `flag` — keep it, colour it as failed (visible reckoning)
- `archive` — move it out of view

This is distinct from `NotDone` (a soft, expected miss). A hard-date miss is a real
failure; a habit miss is just data. (See §6.3 for the two meanings of "fail".)

---

## 4. Template (the factory)

A Template is the recurrence definition. It is **never completed**; it manufactures
Tasks. One-offs are Templates that fire exactly once and stay hidden until the user
chooses "turn into series."

### 4.1 Fields
- `reactivation_rule`: when new Tasks are generated (`daily`, `every 2 weeks`,
  `yearly in March`, `once` for one-offs, …)
- `default_active_window`: the window applied to generated Tasks. Default end =
  *next reactivation date*; the Template may instead specify an explicit duration
  (e.g. "becomes active on the 1st of the month, active for 1 week").
- `pool_id`: which Pool generated Tasks belong to
- `task_defaults`: title, missed_behavior, hard_due_date policy, etc., inherited by
  generated Tasks.

### 4.2 Lazy generation
Templates do **not** materialize the whole future series (unlike Outlook). They
generate **one open Task at a time** (optionally plus the next one as a preview). This
makes "change all future occurrences" trivial: because the next Task only comes into
existence at reactivation, it automatically inherits the current Template definition.

### 4.3 One-off = single-fire Template
A standalone to-do is internally a Template with `reactivation_rule = once`. The
Template stays hidden. When the user taps **"turn into series,"** the Template surfaces
and gains a real reactivation rule. This unifies one-off and recurring into a single
mechanism — the only difference is *one Task* vs. *one Task per reactivation*.

---

## 5. Edit Semantics (Outlook series vs. instance)

The user can edit either a single Task or the whole series, and they behave like
Outlook — which the user already understands without explanation.

### 5.1 Edit this Task (single instance)
Only this instance changes. It becomes an **exception** (`is_exception = true`) and
stops following the Template.

### 5.2 Edit the Template (the series)
Applies **prospectively only** — to Tasks generated *after* the edit. Because of lazy
generation (§4.2), there are essentially no materialized future Tasks to rewrite; the
next generated Task simply inherits the new definition.

> **Currently-open Task:** A Template edit does **not** alter the already-open Task.
> It keeps its current form unless edited directly. Rule: *Template edits take effect
> from the next generated Task onward.* This protects the running instance from
> surprise changes and is the simplest rule to explain.

### 5.3 The conflict rule (exceptions win)
If a Task has already been individually edited (`is_exception = true`), subsequent
Template edits **leave it untouched**. The exception always wins over the series
update. Without this, a series edit would silently overwrite a manual change — exactly
the "the app did something behind my back" failure that destroys trust.

---

## 6. Pool (visibility & organization)

Pools are **not five hard-coded types.** They are presets over a small set of axes.
This is what makes the model generic: a user who thinks differently builds their own
Pool by setting the axes.

### 6.1 Pool axes
| Axis | Values | Meaning |
|------|--------|---------|
| `show_count` | `1` \| `3` \| `all` | How many slots appear in the overview |
| `selection` | `next_due` \| `manual_order` \| `random` \| `all_active` | How a free slot is filled |
| `fail_policy` | `never` \| `on_due_passed` \| `after_n_missed` | When/whether the pool marks a task failed |
| `on_complete` | `hold_until_rollover` \| `advance_immediately` \| `task_reactivates` | What happens to a slot on completion |
| `skip_policy` | `track_only` \| `remove` \| `rotate` \| `requeue_end` | What a skip does to the task's position |
| `period` | `none` \| `week` \| `month` | The cadence for fail/advance (pool-level only) |

### 6.2 Shipped presets
| Preset | show_count | selection | fail_policy | on_complete | skip_policy | period |
|--------|-----------|-----------|-------------|-------------|-------------|--------|
| **Habits** | all | all_active | never | task_reactivates | track_only | none |
| **Hard dates** | 3 | next_due | on_due_passed (terminal) | — (one-off) | remove | none |
| **Week pool** | 1¹ | manual_order / random² | after_n_missed (n=3) | hold_until_rollover | rotate | week |
| **Month pool** | 1¹ | manual_order / random² | after_n_missed (n=3) | hold_until_rollover | rotate | month |
| **Small to-dos** | 3 | manual_order | never | advance_immediately | requeue_end | none |

¹ `show_count` configurable (the user may want more than one per week).
² open: whether a freed slot pulls the next item in order or a random one. Configurable.

> Week and Month pools differ **only** in `period`. This is the proof the axis
> decomposition is correct.

### 6.3 Two meanings of "fail" — kept separate
- **Task-level missed** (§3.4): *terminal, date-driven.* A hard due date passes; the
  task is dead. Per-task: flag or archive.
- **Pool-level rotation** (`fail_policy = after_n_missed`): *organizational,
  slot-driven.* After N not-dones the pool rotates a **new** task into the slot. The
  rotated-out task is **not** dead — it yields its slot and returns to the list.

These never collide because they live on different objects (Task vs. Pool).

### 6.4 Hard-date rotation immunity
A Task with a `hard_due_date` is **immune to pool rotation**. It stays in its slot
until its date or completion, regardless of the Pool's `fail_policy`. **Hard date beats
organizational cadence.** This prevents a rotation policy from cycling away a task that
has a real deadline.

### 6.5 Two meanings of "cyclical" — kept separate
- **Task reactivation** (intrinsic): belongs to the **Template**. Governs *when a task
  becomes active again* (every 2 weeks, yearly in March). It does not care which Pool
  the task lives in or whether that Pool has a period.
- **Pool period** (extrinsic): a **visibility cadence only**.

> A self-reactivating Task **may** live in a periodic Pool. There is no conflict:
> reactivation is a Template concern (*when the task exists*), period is a Pool concern
> (*how it is shown*). Example: window-cleaning reactivates yearly in March, but lives
> in a Weekly pool — it's a larger task the user can *choose* to pull into a given
> week, not something with a weekly cadence of its own.

---

## 7. Constraints & Validation

Some Pool policies presuppose Task fields. These must be validated at configuration
time, not left to fail silently at runtime.

- `selection = next_due` requires member Tasks to have a date to sort by. A Hard-dates
  pool can only admit Tasks with a `hard_due_date`.
- `fail_policy = on_due_passed` requires a `hard_due_date` on the Task — otherwise
  there is no expiry condition to trigger the failure.
- General rule: **Policy X requires Task field Y.** Reject Pool/Task combinations that
  cannot satisfy their own fail/advance condition.

Active-window rule:
- A reactivating Task's `active_window` is optional. If absent, `window.end` defaults
  to the *next reactivation date* — the open Task is closed (as `Skipped`/`NotDone`)
  when the next one is generated. One formula covers both one-off and cyclical.

---

## 8. Evaluation / Tracking

- **All analytics read from Task records only** — the stream of `Done` / `Skipped` /
  `NotDone` outcomes over time. Templates and Pools hold no history.
- Supports: streaks, completion history, "how far behind" counts.
- **Avoidance surfacing:** beyond a threshold of consecutive skips/not-dones, surface
  the item *differently* (e.g. colour) as **information, not a command** — "you've
  pushed this for 6 weeks." This is the honest middle path between forcing the task
  (rigid → drop-reflex) and letting it silently vanish (avoidance wins permanently).

---

## 9. Reminders (behavioural requirement only)

Tech is defined separately, but the conceptual requirement:

- All reminder timings are **locally derivable** from Task active windows and
  reactivation rules. No remote trigger is conceptually required — the device always
  knows when to notify. (Consistent with a local-first, privacy-respecting stance.)
- **Reminders must be rescheduled whenever state changes** — on completion, skip,
  reorder, or new generation. Otherwise reminders fire for tasks that are no longer
  open. This is a hard correctness requirement of the model, independent of the
  notification implementation.

---

## 10. Glossary

| Term | Definition |
|------|------------|
| **Template** | Recurrence definition / factory. Generates Tasks. Never completed. Hidden for one-offs. |
| **Task** | A single completable to-do instance. The only object with a completion status and the only source of analytics. |
| **Pool** | Visibility & organization layer; a preset over the axes in §6.1. |
| **Active window** | `{start, end}` on a Task defining when it is actionable. |
| **Active** | Derived: a Task that is within its window and still `ToDo`. |
| **Exception** | A Task individually edited away from its Template; immune to future Template edits. |
| **Reactivation** | Template-level rule for when a new Task is generated. |
| **Period** | Pool-level visibility cadence (`week`/`month`); unrelated to reactivation. |
| **NotDone** | Automatic outcome when an active window expires while still `ToDo`. Data, not failure. |
| **Missed** | Terminal failure of a hard-dated Task whose due date passed. |

---

## 11. Open questions (deferred, not blocking)

1. Week/Month pool freed-slot fill: next-in-order vs. random — configurable, default TBD.
2. `show_count` per pool: confirm configurable range.
3. "Next task preview" (the +1 lazy-generated Task): shown to the user or internal only?
4. Snooze-until-date as an alternative to manual drag for a temporarily-blocked top
   item (raised as a possible v2; not in v1 scope).
