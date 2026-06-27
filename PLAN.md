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

1. **"Not done" is data, never punishment.** `NotDone` is an automatic, expected
   outcome written when an active window expires. It is the *source* of all analytics
   — without it there is no streak history. This makes the **time-driven expiry sweep a
   core correctness feature**, not a cosmetic background job.
2. **Anti-rigidity.** The simple case (one daily habit) must show zero complexity. Power
   (pools, recurrence, hard dates) is summoned, never imposed. Build order reflects this:
   the trivial daily-habit surface ships first and stands alone.
3. **The app must never act behind the user's back.** Exceptions win over series edits;
   reminders are rescheduled on every state change; sweeps are idempotent. Trust is the
   product.

## Decisions (from planning)

| Area | Decision |
|---|---|
| Framework | **Flutter** (Android-first, iOS-capable), same toolchain as knabberfuchs |
| State | **Riverpod** (v3) |
| Persistence | **drift / SQLite**, local-first, with migrations |
| Design | **Material 3**, own seed colour (fox-orange, TBD — not the knabberfuchs green) |
| Networking | **None.** Fully on-device. Every reminder time is *locally derivable* from windows + reactivation rules (concept §9) — no server, no push, no account |
| Reminders | **`flutter_local_notifications` + `timezone`**, rescheduled on every state change |
| Domain core | A **pure, side-effect-free engine** over an injected `Clock`. The DB and notifications are driven *from* it, never mixed into it — so the whole state machine is unit-testable with a fake clock |
| l10n | **en/de/fr/it** from day one, no hardcoded user-facing strings (knabberfuchs rule) |
| Backup | **ZIP** = SQLite snapshot + JSON export; fully local, no cloud lock-in (mirror knabberfuchs) |
| App id | `ch.checkfuchs.app` |
| Repo | `Kemenor/checkfuchs`, public |

## Architecture

```
lib/
  core/            theme, clock, formatting, l10n glue, result types
  data/
    db/            drift tables + DAOs + migrations
    repositories/  template / task / pool repos (DB ⇄ domain)
    backup/        ZIP snapshot + JSON export/import
  domain/          PURE engine — state machines, generation, expiry, rotation,
                   validation. No Flutter, no drift, no I/O. Injected Clock.
  notifications/   schedule/reschedule local reminders from domain output
  ui/
    today/         the daily surface (the carrier — Forced tier)
    pools/         pool list + per-pool views + axis config
    task/          task detail, edit-this-vs-series (Outlook semantics)
    template/      recurrence editor ("turn into series")
    analytics/     streaks, history, avoidance surfacing
    settings/      backup/restore, language, about
  l10n/            app_en.arb (template) + de/fr/it mirrors
```

**The engine is the heart.** Everything time-sensitive lives in `domain/` as pure
functions over `(state, now)`:

- **Generation** — for each active Template, ensure exactly one *open* Task exists
  (Pending or Active), optionally +1 preview. Lazy: the next Task is materialized only at
  reactivation, which is what makes "edit all future occurrences" free (concept §4.2).
- **Expiry sweep** — any Active `ToDo` whose `window.end < now` becomes `NotDone`
  (terminal); a `hard_due_date` that passes becomes `Missed` (terminal failure). Both
  trigger regeneration. **Idempotent**: running it twice changes nothing.
- **Pool rotation** — `after_n_missed` pools rotate a fresh Task into a freed slot after
  N consecutive `NotDone`s; the rotated-out Task is *not* dead. Hard-dated Tasks are
  **immune** (concept §6.4).
- **Validation** — reject Pool/Task combinations that can't satisfy their own policy
  (e.g. `fail_policy = on_due_passed` requires a `hard_due_date`; concept §7), at config
  time, not runtime.

**Run cadence:** the sweep + generation run on app foreground, on midnight rollover
(via a scheduled local check), and after every user action. Because it's pure and
idempotent, "run it whenever in doubt" is always safe.

### Schema (drift, first cut)

Three tables mirror the three objects. **Analytics read from `tasks` only** — terminal
Tasks persist and *are* the history; there is no separate history table (concept §8).

**`pools`** — visibility/org as presets over axes (concept §6.1), not hard-coded types:
`id, name, preset_label, show_count (1|3|-1=all), selection (next_due|manual_order|
random|all_active), fail_policy (never|on_due_passed|after_n_missed), fail_n,
on_complete (hold_until_rollover|advance_immediately|task_reactivates), skip_policy
(track_only|remove|rotate|requeue_end), period (none|week|month), sort_index`.

**`templates`** — the factory (concept §4): `id, title, pool_id→pools,
recurrence_kind (once|daily|every_n_days|weekly|every_n_weeks|monthly|yearly|custom),
recurrence_interval, recurrence_anchor (json: weekday/day-of-month/month), window_start_rule,
window_duration (null ⇒ end = next reactivation date), task_defaults (json:
missed_behavior, hard_due policy…), surfaced (false ⇒ hidden one-off until "turn into
series"), archived, created_at`.

**`tasks`** — the instance & sole completion record (concept §3): `id,
template_id→templates (nullable), pool_id→pools (snapshot at generation), title
(snapshot), completion_status (toDo|done|skipped|notDone), window_start, window_end
(nullable), hard_due_date (nullable), missed_behavior (flag|archive, snapshot),
is_exception (bool), manual_order (int, for manual_order pools), resolved_at, created_at`.

Snapshotting title/pool/missed_behavior onto the Task is what makes **exceptions** (a
Task edited away from its Template) and immutable history both trivial: editing a Template
never rewrites an open or past Task.

## Roadmap (phased)

Ordered so the **carrier mechanism ships first and stands alone**, then the three
visibility tiers (Forced → Self-announcing → Passive) layer on. Each phase is releasable.

- **Phase 0 — Scaffold.** Flutter project (`ch.checkfuchs.app`), Riverpod, M3 theme, l10n
  skeleton (en/de/fr/it), distrobox + CI (`flutter analyze` + `flutter test`), public
  repo, empty app shell that boots. *Done = green CI, app launches to an empty Today.*
- **Phase 1 — Domain engine + DB.** drift schema (pools/templates/tasks) + DAOs +
  migrations; the pure engine (generation, expiry sweep, the Pending→Active→
  Done|Skipped|NotDone state machine) over an injected `Clock`. **Heavy unit tests** with
  a fake clock — this is where correctness lives. No real UI (a debug screen is fine).
- **Phase 2 — Today surface (Forced tier / MVP).** A single Habits pool: today's active
  Tasks listed; check off `Done`/`Skip`; expired windows auto-write `NotDone` on open.
  This alone is a usable daily-habit tracker and proves the carrier. *First dogfood build.*
- **Phase 3 — Templates & recurrence.** Create a habit / recurring task; reactivation
  rules (daily, every N weeks, yearly-in-March…); the Outlook **edit-this-Task vs
  edit-the-series** model with exceptions winning over series edits (concept §5).
- **Phase 4 — Pools & axes.** The full axis model + shipped presets (Habits, Hard dates,
  Week, Month, Small to-dos); pool config UI; rotation / advance / skip / on-complete
  policies; config-time validation (concept §6–§7). One-off ↔ series ("turn into series").
- **Phase 5 — Hard dates (Self-announcing tier).** `hard_due_date`, `missed_behavior`
  (flag|archive), rotation immunity, and surfacing a dated item into Today only as its day
  approaches (concept §1.4, §3.4, §6.4).
- **Phase 6 — Reminders.** Local notifications derived from windows/reactivation;
  **rescheduled on every state change** (the hard correctness requirement, concept §9).
- **Phase 7 — Analytics & avoidance.** Streaks, completion history, "how far behind"
  counts from the Task stream; **avoidance surfacing** — past a consecutive-skip threshold,
  show the item *differently* (colour) as information, never a forced action (concept §8).
- **Phase 8 — Polish & i18n.** Full DE/FR/IT microcopy, ZIP backup/restore, settings,
  onboarding that creates the first daily habit (seed the carrier), landing page on
  checkfuchs.ch.
- **Phase 9 — Release.** App icon, fastlane metadata, store listing, signing; closed test.

## Open questions (from concept §11, to resolve as we hit them)

1. Week/Month pool freed-slot fill: next-in-order vs. random — configurable, default TBD.
2. `show_count` configurable range per pool.
3. "+1 next-task preview": shown to the user or internal only?
4. Snooze-until-date for a temporarily-blocked top item — v2 candidate, not v1.
5. Seed colour / fox identity for Checkfuchs (must differ from knabberfuchs green).
