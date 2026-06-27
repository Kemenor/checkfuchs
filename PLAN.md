# Checkfuchs — Plan

A combined **habit + to-do** app built on one insight: habits and to-dos are *one
mental object* with different time horizons. A single unavoidable daily habit is the
**carrier** that guarantees the app gets opened every day, keeping dated items and the
backlog visible. Android-first (Flutter, so iOS stays possible). Local-first, serverless,
no accounts, no ads.

The conceptual data model is frozen in [`design-concept.md`](./design-concept.md) — that
doc owns the *what* (objects, state machines, edit semantics). **This doc owns the
*how*:** stack, schema, engine, and the phased build order. When the two disagree, the
concept wins for semantics; this plan wins for implementation.

## Philosophy carried into the build

Three principles from the concept that shape *technical* decisions, not just UX:

1. **The separation law is the spine.** Template owns *generation*, Task owns *all
   status*, Lens is *pure presentation*. Most bugs in a model like this come from a Lens
   reaching into status — the schema and the engine are built so that's structurally
   impossible.
2. **"Not done" is data, never punishment.** `Missed` is an automatic, expected outcome
   written when a window expires. It is the *source* of all analytics — so the
   time-driven **expiry sweep is a core correctness feature**, not a cosmetic job.
3. **The app never acts behind your back.** Stored Tasks win over projection; reminders
   reschedule on every state change; sweeps are idempotent. Trust is the product.

## Decisions (from planning)

| Area | Decision |
|---|---|
| Framework | **Flutter** (Android-first, iOS-capable), same toolchain as knabberfuchs |
| State | **Riverpod** (v3) |
| Persistence | **drift / SQLite**, local-first, with migrations |
| Design | **Material 3**, own **fox-orange** seed (TBD — *not* the knabberfuchs green) |
| Networking | **None.** Fully on-device. Every reminder is *locally derivable* from a Task's `notifications` + window — no server, no push, no account |
| Reminders | **`flutter_local_notifications` + `timezone`**, rescheduled on every state change |
| Domain core | A **pure, side-effect-free engine** over an injected `Clock`. DB + notifications are driven *from* it, never mixed *into* it — so the whole state machine and the generation/projection logic are unit-testable with a fake clock |
| Generation | **Lazy: materialize the current instance, project the future as virtual, materialize-on-action.** A stored Task always wins over its virtual projection |
| l10n | **en/de/fr/it** from day one, no hardcoded user-facing strings |
| Backup | **ZIP** = SQLite snapshot + JSON export; fully local, no cloud lock-in |
| App id | `ch.checkfuchs.app` |
| Repo | `Kemenor/checkfuchs`, public |

## Architecture

```
lib/
  core/            theme, clock, formatting, l10n glue, result types
  data/
    db/            drift tables + DAOs + migrations
    repositories/  template / task / lens / vacation repos (DB ⇄ domain)
    backup/        ZIP snapshot + JSON export/import
  domain/          PURE engine — Task state machine, generation (project + materialize-
                   on-action), expiry sweep, recurrence math, lens projection,
                   validation. No Flutter, no drift, no I/O. Injected Clock.
  notifications/   schedule/reschedule local reminders from domain output
  ui/
    lenses/        lens views (the daily surface is just a pinned Lens) + lens config
    task/          task detail, edit-this-instance vs edit-the-series
    template/      recurrence + window-rule editor ("turn into series")
    analytics/     completion rate, history, avoidance surfacing
    settings/      pause, vacation, backup/restore, language, about
  l10n/            app_en.arb (template) + de/fr/it mirrors
```

**The engine is the heart.** Everything time-sensitive lives in `domain/` as pure
functions over `(state, now)`:

- **Generation** — for each *active* Template (`NOT paused AND NOT vacationActive`),
  ensure exactly one *current* open instance exists; future occurrences stay **virtual**
  (projected from the recurrence rule). Acting on a virtual occurrence **materializes**
  it. This is what makes "edit all future occurrences" free — there's nothing materialized
  to rewrite.
- **Expiry sweep** — any `Open` Task whose `end < now` becomes `Missed` (terminal, stamps
  `resolvedAt`), which triggers regeneration of the next instance. **Idempotent**:
  running it twice changes nothing.
- **Lens projection** — a pure function from `(membership rows, dials, now)` to the shown
  set, applying `ordering` → `selection` → `showCount`, plus periodic hold-till-rollover,
  `Pass`, and `Dormant`. **Reads status, never writes it.**
- **Validation** — reject combinations that can't satisfy their own condition (a
  `start`-anchored notification needs a `start`; `ordering = dueDate` needs dated members).

**Run cadence:** the sweep + generation run on app foreground, on midnight rollover, and
after every user action. Because they're pure and idempotent, "run them whenever in
doubt" is always safe.

### Schema (drift, first cut)

Seven tables. **Analytics read from `tasks` only** — terminal Tasks persist and *are* the
history; there is no separate history table.

**`templates`** — the factory (concept §3): `id, name, note, recurrence (freq,
interval, byWeekday[], byMonthDay, byMonth, anchor), window_rule (kind + params),
notifications (json), paused, resume_on, created_at`. Holds the *defaults* it stamps onto
generated Tasks.

**`tasks`** — the instance & sole completion record (concept §2): `id, template_id
(nullable; null = standalone one-off), occurrence_key (which slot this instance fills, so
a stored Task can shadow its virtual projection), name, note, status (Open|Done|Skipped|
Missed), start (datetime?), end (datetime?), notifications (json), created_at,
resolved_at`.

**`lenses`** — pure presentation (concept §4): `id, name, show_count, ordering
(dueDate|manual|automatic), selection (top|random), period (none | recurrence json),
dormant_after, created_at`.

**`task_lens`** — the membership join (many-to-many): `task_id, lens_id, order,
dormancy_counter, passed_this_period`. Templates also carry **default** lens memberships
(`template_lens_defaults: template_id, lens_id, default_order`) that seed each instance's
join rows.

**`views`** — the screen layer (concept §4.6): `id, name, sort_index`. Top-level
navigation; user-composed.

**`view_lens`** — the membership join (many-to-many): `view_id, lens_id, order,
status_filter` (which terminal states surface alongside open tasks; default open-only).

**`vacations`** — app-level (concept §6): `id, start, end`. A list of periods; generation
is gated when `now` falls in any of them.

> No `is_exception`, no status on Lens, no `pool` axes that touch lifecycle — the schema
> *enforces* the separation law.

## Roadmap (phased)

Ordered so the **carrier mechanism ships first and stands alone**. Each phase is
releasable. Note the model collapsed some of the old plan's phases: "hard dates" is no
longer special (just a Task with an `end` shown in a due-date Lens), and the three
visibility tiers are now Lens configurations, not code paths.

- **Phase 0 — Scaffold.** Flutter project (`ch.checkfuchs.app`), Riverpod, M3 theme +
  fox-orange seed, l10n skeleton (en/de/fr/it), distrobox + CI (`flutter analyze` +
  `flutter test`), empty app shell that boots. *Done = green CI, app launches.*
- **Phase 1 — Domain engine + DB.** The pure engine over an injected `Clock`: the Task
  state machine, the expiry sweep, generation (materialize-current + virtual projection +
  materialize-on-action), recurrence math, lens projection. drift schema (the five
  tables) + DAOs + migrations. **Heavy unit tests** with a fake clock — this is where
  correctness lives. No real UI (a debug screen is fine).
- **Phase 2 — First Lens + Task surface (MVP / the carrier).** One continuous
  "everything" Lens showing today's active habit Tasks; check `Done`/`Skip`; expired
  windows auto-write `Missed` on open. This alone is a usable daily-habit tracker and
  proves the carrier. *First dogfood build.*
- **Phase 3 — Templates & recurrence.** Create a habit / recurring task; the RRULE-shaped
  recurrence editor; window rules (slice / duration / default); **edit-this-instance vs
  edit-the-series** (free, thanks to virtual projection); "turn a one-off into a series."
- **Phase 4 — Lenses, Views & dials.** The full Lens model: `showCount`, `ordering`,
  `selection`, `period` (continuous vs periodic hold-till-rollover), `dormantAfter`;
  `Task↔Lens` membership + order persistence; the **Pass** and **Dormant** behaviours;
  config-time validation. (Due-date Lens covers what used to be "hard dates.") Plus
  **Views** (concept §4.6) as user-composed screens of Lenses with per-lens `statusFilter`,
  driving top-level navigation.
- **Phase 5 — Reminders.** The `notifications` array → local notifications, **rescheduled
  on every state change** (concept §9). Friendly presets (start / upcoming / due /
  reminder) over the general `(anchor, offset)` form.
- **Phase 6 — Pause & Vacation.** Per-Template `paused` + `resumeOn`; app-level
  `vacations` periods; the generation gate (treadmill only — hard deadlines still
  `Miss`); resolve the vacation-start auto-`Skip` detail.
- **Phase 7 — Analytics & avoidance.** Completion-rate over a window, streaks (`Skip`
  neutral, `Missed` breaks gently), "how far behind" counts; **avoidance surfacing** —
  past a consecutive-miss threshold, render the item *differently* (colour), never a
  forced action (concept §8).
- **Phase 8 — Polish & i18n.** Full DE/FR/IT microcopy, ZIP backup/restore, settings,
  onboarding that seeds the first daily habit (the carrier), landing page on
  checkfuchs.ch.
- **Phase 9 — Release.** Fox icon, fastlane metadata, store listing, signing; closed test.

## Open questions (from concept §11, resolve as we hit them)

1. Periodic-Lens freed-slot fill when `selection = top` vs `random` — default TBD.
2. `showCount` configurable range per Lens.
3. Vacation-start handling of the already-open instance: auto-`Skip` (leaning) vs leave.
4. Snooze-until-date for a temporarily-blocked top item — v2 candidate.
5. Smart/filter Lenses (auto-membership by query) atop explicit membership — later.
6. Seed colour / fox identity for Checkfuchs (must differ from knabberfuchs green).
