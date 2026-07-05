# Checkfuchs — Full Repository Review

*Date: 2026-07-06 · Scope: entire repo (domain, data, UI, l10n, config, CI, docs) · Baseline: `main` @ `1acbaec`*

> ## Resolution — 2026-07-06 (same day)
>
> **All findings below were fixed** in the working tree (uncommitted): H1–H4, M1–M14,
> L1–L17, L19, plus the test-coverage gaps (suite grew 93 → **135 green**, analyze clean,
> repo `dart format`-clean, CI drift/format guards added and verified). Also fixed beyond
> this review: avoidance surfacing (PLAN Phase 7 claimed it; the UI half was missing) and
> PLAN.md's stale schema/state lines. Schema bumped to **v4** (`task_lens.passed_at`
> replaces `passed_this_period`; `PRAGMA foreign_keys` now ON).
>
> Deliberately not "fixed":
> - **L18** — fuchsbau still pins `ref: main`: the upstream repo has **no tags** to pin
>   to (lockfile pins a commit, so builds stay reproducible). Tag fuchsbau, then pin.
> - **M13** — release signing is now the conditional `key.properties` pattern; an actual
>   release keystore remains a Phase 9 task (debug fallback until then, clearly commented).
> - **L20** — informational Phase-5 landing checklist (unchanged); the landing page still
>   loads Google Fonts (cosmetic, site not app).
> - Lens dial-editing / statusFilter UI stays deferred (a PLAN deferral, not a defect) —
>   periodic/random lens behaviour is engine-complete + tested but not yet configurable.
> - Full v1→v4 migration verification: smoke tests only (schemaVersion, pragma, tables);
>   drift's exported-schema test harness is a follow-up.
> - ~~Design-concept open question #3 kept as-is~~ **Resolved as auto-Skip** (follow-up,
>   same day): an open instance whose window can't survive a vacation is Skipped —
>   neutral, streak-preserving, stamped at the vacation start — instead of decaying into
>   a Miss; windows that outlast the vacation stay open, one-off deadlines still pass.
>   Pinned by engine + repository tests.

**Health snapshot:** `flutter analyze` clean · all 93 tests green (matches PLAN.md's claim) · no secrets tracked · lockfile committed · CI pins an exact Flutter version.

**Overall:** This is an unusually tidy pre-release solo codebase. The layering genuinely enforces the "separation law" — the domain engine is pure, well-documented, and its hardest unit (the recurrence generator) is solid: civil-date reconstruction and UTC epoch-day math make the core date arithmetic DST-safe, and interval anchoring / month-overflow clamping are correct. The systemic weaknesses are concentrated in four places: **(1)** the reconcile engine doesn't know *when* generation was gated, so pause/vacation resume retroactively writes `Missed` records; **(2)** no write path uses a transaction and foreign-key enforcement was never switched on; **(3)** the view/lens projection is computed against a clock frozen at app launch; **(4)** about half of the lens semantics (periodic hold, Pass, dormant resurfacing) exist as schema fields and doc comments but not as logic. All are cheap to fix now and expensive to fix after more features stack on top.

---

## High severity

### H1. Resuming from pause/vacation back-fills the entire gap as `Missed`
`lib/domain/generation.dart:49-77`

The pause/vacation gate is evaluated only at `now`:

```dart
if (!t.generatesAt(now) || vacationActive) return ReconcileResult(changed);
```

The back-fill loop then generates every occurrence since the latest stored one (`occurrenceAfter(t.recurrence, latest)`) and expires each (`expireIfDue`), with no knowledge of when generation was suspended. **Scenario:** daily habit, vacation July 1–14. During the break nothing generates — correct. On July 15 the first reconcile finds the latest occurrence = June 30 and back-fills July 1–14 as **14 `Missed` tasks**, cratering the completion rate and setting `consecutiveMisses = 14` (triggering avoidance styling). The caller can't compensate: `reconcileAll` (`lib/data/repositories/task_repository.dart:187-200`) passes only a boolean `vacationActive` at `now`; past vacation periods never reach the engine.

This contradicts design-concept §6 and the product's core "not done is data, never punishment" principle — here pausing *creates* punishment data. Fix: per-occurrence gating (skip occurrences whose window fell inside a pause/vacation period) or a generation floor at resume — the brand-new-template path (`_firstActionableOccurrence`) already shows the right pattern. **No test covers resume-after-gap.**

### H2. Foreign keys are never enabled — every `onDelete` action is decorative
`lib/data/db/database.dart:133-158`

SQLite defaults to `PRAGMA foreign_keys = OFF` and drift does not turn it on; there is no `beforeOpen` callback (verified: zero matches for `PRAGMA`/`beforeOpen`/`foreign_keys` in `lib/`). **Scenario:** `deleteTask()`/`deleteTemplate()` leave orphaned `task_lens` rows forever (the declared `KeyAction.cascade` at `database.dart:74-77` never fires); once lens deletion ships, `templates.defaultLensId` (`KeyAction.setNull`) keeps pointing at a dead lens, so `reconcileAll` inserts memberships into a nonexistent lens and new instances become invisible in every view. Fix:

```dart
MigrationStrategy(beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'))
```

### H3. No write path uses a transaction; `reconcileAll` is racy and non-atomic
`lib/data/repositories/task_repository.dart:187-213` (also `53-58`, `103-107`, `111-122`; `lib/data/repositories/view_repository.dart:47-72`)

`reconcileAll` runs dozens of dependent reads/writes with no `db.transaction` (verified: zero uses of `transaction` in `lib/`). Two concrete failures:

1. **Duplicate instances** — `reconcileAll` is invoked concurrently from several UI paths (resume in `home_shell.dart:48`, `create_task_sheet.dart:91`, complete/skip on rapid swipes). Two overlapping calls both read `existing` before either inserts, both see no open instance, both insert one → two open tasks for the same occurrence. The existing idempotency test (`task_repository_test.dart:48`) only covers sequential calls.
2. **Lost membership** — if the process dies between the task insert and `addMembership`, the task exists with no `task_lens` row; the next reconcile sees an open instance and never re-adds it → the task is permanently invisible in all lenses.

Same pattern elsewhere: `createTask` (insert + membership), `deleteTemplate` (two deletes), `turnIntoSeries` (create + delete + reconcile), and `view_repository.seedDefaults` — where a partial seed is *permanent*, because the idempotency guard only checks `lenses`: killed after the lens insert but before the view insert, every later launch hits `existing.isNotEmpty` and returns early, so the app never gets a Home view. Wrap each in `db.transaction`; drift's transaction queueing also serializes the reconcile race.

### H4. `viewStateProvider` freezes `now` at first build — the home surface goes stale across day boundaries
`lib/providers.dart:45-49` (confirmed independently by two reviewers)

`watchViewState(viewId, ref.read(clockProvider).now())` captures `now` once when the non-`autoDispose` family provider is created; every subsequent stream emission is projected with that original timestamp (`view_repository.dart:110-114` → `projectLens`/`isDormant`). **Scenario:** an app kept alive (or backgrounded — resume triggers `reconcileAll`, which writes and re-emits, but still through the frozen-`now` projection) across a day boundary keeps rendering yesterday's shown/pending set and computes dormancy against launch-day `now` until a full process restart. Nothing ever calls `ref.invalidate(viewStateProvider)`. `TaskTile` has the same shape in miniature (`task_tile.dart:20`): phase is computed from build-time `now` and only refreshes on unrelated stream emissions, so a pending task whose window opens never becomes tappable on its own. For a habit app this is the core loop; PLAN.md's "foreground time advance" timer (§Derived state) is designed but unimplemented.

---

## Medium severity

### Domain / product semantics

- **M1. Periodic "hold-till-rollover" is not implemented — all lenses behave as continuous.** `lib/domain/derive.dart:41`, `lib/domain/lens.dart:71`. `projectLens` filters `m.task.isOpen` unconditionally, so completing a periodic lens's top item immediately refills the slot instead of holding "nicely done" until rollover (design-concept §4.3). PLAN marks Phase 4 done (MVP) with this in scope.
- **M2. The Pass verb has no effect.** `lib/domain/derive.dart:34-53`. `passedThisPeriod` is plumbed from the DB into `LensMember` but `projectLens` never reads it, and no code path ever writes it `true` — "show me another this period" (§4.4) doesn't exist.
- **M3. Dormant members never resurface, and dormancy accrues without ever being shown.** `lib/domain/derive.dart:25-31`. `isDormant` is monotonic and nothing ever re-stamps `surfacedAt` (set once at membership creation). §4.4 says dormant items "resurface later." Scenario: 10-member weekly lens, `showCount: 2`, `dormantAfter: 3` — after 3 weeks members 3–10 all go dormant *without ever having been displayed*, and none come back.
- **M4. (Latent) `latest = max(occurrence)` skips gaps once non-contiguous materialization exists.** `lib/domain/generation.dart:63-65`. If a *future* occurrence is materialized-on-action (pre-Skip, per §3.4), reconcile advances from the max, so intermediate slots silently vanish from history (never open, never Missed). Latent today — no UI path creates non-contiguous future tasks yet — but it will break the moment pre-skip ships. Advance from the earliest unfilled slot instead.

### Data layer

- **M5. `turnIntoSeries` drops the one-off's lens memberships.** `lib/data/repositories/task_repository.dart:111-122`. `createTemplate` falls back to the global default lens; the original task's `task_lens` rows are never consulted. A one-off living in a custom "Fitness" lens converts to a series whose instances all land in "All tasks."
- **M6. `watchViewState` reads the `ViewRow` once, outside the stream.** `lib/data/repositories/view_repository.dart:107-114`. The join never watches `views`, so a future view rename/delete would never be reflected. Latent (no rename API yet) but a trap.

### UI

- **M7. A one-off can be born already expired — and then it's untouchable.** `lib/ui/create_task_sheet.dart:40-51`. `oneOffWindow` anchors slices to *today* unconditionally: create a "Morning" one-off at 14:00 → `start=00:00, end=12:00`, phase `expired` at birth. It can't be completed (`canComplete` false) or skipped (`skipTask` no-ops), and it's never auto-Missed because `reconcileAll` iterates templates only — standalone tasks have no expiry path. Only manual delete removes the dead row. (Two fixes needed: roll past slices to tomorrow at creation, and give standalone tasks an expiry path in reconcile.)
- **M8. The detail sheet renders a stale snapshot after "Make it a habit" / "Stop repeating."** `lib/ui/task_detail_sheet.dart:76-78, 123-125`. The sheet keeps `widget.task` from open time; after `turnIntoSeries` completes underneath it, it still shows "Make it a habit," hides the Paused toggle and series delete, and never loads streak stats.
- **M9. `TaskTile` is status-blind — terminal tasks render as open rows.** `lib/ui/task_tile.dart:23-27`. `LensSection.shown` can include Done/Skipped/Missed (via a view's `statusFilter`), but the tile switches only on time-phase: terminal tasks would get the open ring and a live swipe-to-Skip. DESIGN_SYSTEM §2's locked status markers (emerald `check_circle`, `remove_circle_outline`, struck taupe) are unimplemented. Latent (no UI sets `statusFilter` yet).
- **M10. l10n is wired but bypassed by ~95% of strings.** Four .arb locales and delegates exist, but only 4 keys are used; nearly every user-facing string is hardcoded English (`home_shell.dart:90-93, 256-262, 305-313`; `create_task_sheet.dart`; `task_detail_sheet.dart:101-153`; `recurrence_editor.dart:105-109, 216-229` — including English month names where `DateFormat.MMMM` should be used; `settings_screen.dart`; `vacation_screen.dart`; `task_tile.dart:49, 70`). *Acknowledged in PLAN.md Phase 8 ("New UI strings are English-only pending the i18n pass"), but it contradicts the day-one "no hardcoded user-facing strings" decision (PLAN §Decisions) and several strings (`'$done done'`) aren't pluralizable as written — the debt gets more expensive per screen.*

### Config / CI / docs

- **M11. CI has no guard against stale drift codegen.** `.github/workflows/ci.yml:19-22`. `database.g.dart` is committed, but CI never runs `build_runner` — edit `database.dart` without regenerating and CI stays green. Add `dart run build_runner build --delete-conflicting-outputs` + `git diff --exit-code`. (l10n gets this right: ignored + regenerated in CI.) Also missing: a `dart format --set-exit-if-changed .` step.
- **M12. App ID mismatch: Android `ch.checkfuchs.app` vs iOS `ch.checkfuchs.checkfuchs`.** `android/app/build.gradle.kts:18` vs `ios/Runner.xcodeproj/project.pbxproj:385`. PLAN.md specifies `ch.checkfuchs.app`; iOS deviates. Effectively immutable post-release — align before Phase 9.
- **M13. Release builds are debug-signed.** `android/app/build.gradle.kts:26-32` (`signingConfig = signingConfigs.getByName("debug")`, with a TODO). Known and scheduled for Phase 9; noted because a debug-signed build installed on a device can't later be upgraded in place by the real release key.
- **M14. README status is ~7 phases stale.** `README.md:48` says "Phase 0 (scaffold) is done; the domain engine is next" while PLAN.md (verified accurate against the code) shows Phases 0–4, 6, 7 done, 5 logic-done, 8 partial. README also lists `flutter_local_notifications` in the stack (`README.md:37`) though it isn't yet a dependency.

---

## Low severity

**Domain**
- **L1.** Duration-add windows drift across DST: `Slice`/`FixedDuration` add absolute `Duration`s to local `DateTime`s (`lib/domain/window_rule.dart:37-40, 51-54`). Fall-back Sunday: `Slice.allDay` ends at 23:00 (an 23:30 evening completion is impossible, auto-Missed an hour early); spring-forward: `morning` ends 13:00, `allDay` overlaps the next window. The Slice doc accepts this for v1, but `FixedDuration` has the same flaw undocumented, and there are zero DST tests. (`UntilNextOccurrence` and all of `recurrence.dart` are DST-safe.)
- **L2.** Yearly recurrence summary prints the `lastDayOfMonth` sentinel: "Every year on **-1** February" (`lib/domain/recurrence_summary.dart:56-59`); the monthly branch handles it, the yearly branch doesn't.
- **L3.** No range validation on `byMonthDay`/`byMonth`/`byWeekday` (`lib/domain/recurrence.dart:34-42`), contradicting design-concept §7: `byMonthDay: 0` rolls into the previous month, `byMonth: 13` into the next year; only `interval >= 1` is asserted, debug-only.
- **L4.** `Task.copyWith` uses `?? this.x`, so nullable fields (`end`, `note`, `resolvedAt`, `occurrence`) can never be cleared (`lib/domain/task.dart:60-84`) — blocks any future "remove due date" edit or the §11.7 Missed→Done correction.
- **L5.** `_maxBackfill` comment is backwards: on guard exhaustion it's the *newest* occurrences including the current open instance that aren't created (empty daily surface until next reconcile), not "the oldest gap" (`lib/domain/generation.dart:25-27`). Cosmetic at 1200 iterations.
- **L6.** `LensSelection.random` never rotates: `randomSeed` defaults to 0 and the only caller (`view_repository.dart:147`) never passes one (`lib/domain/derive.dart:38, 44-45`) — a "random" lens shows the same pick every period. Derive the seed from the rollover count.

**Data**
- **L7.** `completeTask`/`skipTask` write the entire 10-column companion from a possibly stale in-memory `Task` (`task_repository.dart:77-92`), clobbering concurrent field edits (e.g. a rename landing mid-swipe gets reverted). Write only `status` + `resolvedAt`.
- **L8.** `WindowRuleConverter.fromSql` silently maps unknown/corrupt `kind` to `UntilNextOccurrence` (`lib/data/db/converters.dart:52`), masking corruption or a forgotten migration as a behavior change.
- **L9.** `createLensInView` never sets `sortIndex` (defaults 0), so user-created lenses tie and section order is SQLite-arbitrary (`view_repository.dart:80-89`); `createView`'s `count.length` scheme will also produce duplicate indexes once deletion exists.
- **L10.** `SettingsController` lost-update race: `build()` fires `_load()` unawaited; a user change made before the DB read resolves gets overwritten by the stale stored row (`lib/providers.dart:65-82`).
- **L11.** `watchTasks` docstring says "newest occurrence first" but orders by `createdAt desc`; back-filled instances share one `createdAt`, so their relative order is an undefined tiebreak (`task_repository.dart:22-25`).
- **L12.** Dead schema: `taskLens.passedThisPeriod` is never written `true` (see M2), and both lens-creation sites hardcode `LensSelection.top`, making `random` unreachable from the UI.

**UI**
- **L13.** `_promptName` disposes its `TextEditingController` the moment `showDialog` resolves, while the pop transition may still render the field (`lib/ui/home_shell.dart:295-318`) — intermittent "used after being disposed" in debug builds.
- **L14.** `CheckfuchsTheme` (`lib/core/theme.dart:11-12`) is dead code that diverges from `main.dart:22-23` (omits the `font` parameter) — a future caller would silently drop the accessibility-typeface setting. Delete or route `main.dart` through it.
- **L15.** Raw `'$e'` exception text shown to users on stream errors (`home_shell.dart:102, 193`).
- **L16.** DESIGN_SYSTEM deviations: swipe reveals only Skip, not Done · Skip (§3.1, `task_tile.dart:29-39`); breakdown header's `missed` segment isn't taupe (§3.2, `home_shell.dart:234-239`); recurrence editor lacks the "Starts" anchor row (§3.5); pending shows lowercase `'soon'` instead of the uppercase tinted pill (§3.6, `task_tile.dart:69-72`).
- **L17.** Accessibility: no tooltip/semantic label on the complete-ring `IconButton` (the app's primary action, `task_tile.dart:56-64`), the vacation delete button, or the recurrence stepper +/− buttons.

**Config / hygiene**
- **L18.** `fuchsbau` git dependency tracks `ref: main` (`pubspec.yaml:25-28`); the lockfile pins a commit so builds are reproducible, but any `pub upgrade` silently jumps. Pin a tag once its API settles.
- **L19.** `cupertino_icons` is unused (template leftover); `.metadata` is gitignored (Flutter recommends committing it); `gradle.properties` asks for `-Xmx8G` (will thrash small CI runners if an Android build job is added); CI has no periodic `flutter build apk` job, so AGP 9.0.1 / Kotlin 2.3.20 breakage would go unnoticed; GitHub Actions pinned by tag, not SHA.
- **L20.** Phase 5 landing checklist (not a bug today — `flutter_local_notifications` is correctly absent): when the plugin lands it needs core-library desugaring, `POST_NOTIFICATIONS` / exact-alarm permissions, and boot receivers, or reminders will compile but never fire after reboot / on Android 13+. The landing page loads Google Fonts — a third-party request on a "nothing leaves the phone"-branded site (cosmetic).

---

## Test coverage gaps

The 93 existing tests are clean and target real edge cases, but they cover only the happy paths of the scenarios where the remaining bugs live:

- **Resume-after-gap** (would have caught H1): reconcile after a pause/vacation period ends.
- **Concurrency**: the `reconcileAll` duplicate-instance race (existing idempotency test is sequential only).
- **DST boundaries** for `Slice`/`FixedDuration` windows (would have caught L1).
- **Converters**: no direct unit tests — `FixedDuration`, `UntilNextOccurrence`, weekly `byWeekday` sets, `byMonthDay: -1`, `byMonth` are never round-tripped through SQL.
- **Migrations**: schema is at v3 with dogfooding data implied, but no drift schema-verification test asserts v1→3 / v2→3 equals `onCreate` — the classic silent-data-loss vector.
- **Misc**: non-contiguous stored future task (M4); `_maxBackfill` exhaustion; yearly `lastDayOfMonth` / Feb-29 anchor; `periodsElapsed` at exact rollover or `now < from`; `computeStats(since:)` (untested and unused by the UI — §8 wants completion rate *over a window*); weekly multi-day with `interval > 1`; `showCount: 0`; `statusFilter`/`_terminalMatches`; `SettingsController` persistence.
- **Hygiene**: `view_repository_test.dart` and `widget_test.dart` never close their in-memory databases (the task-repo test does; add `tearDown`/`addTearDown(db.close)`).

---

## Suggested order of attack

1. **H2 + H3** — one `beforeOpen` pragma and `db.transaction` wrappers; smallest diffs, closes the data-integrity class before more write paths are built.
2. **H1** — per-occurrence pause/vacation gating + a resume-after-gap test; this is the product's core promise.
3. **H4** — implement the PLAN's designed foreground-timer / `now`-refresh (invalidate the provider on reconcile with a fresh clock read).
4. **M7** (born-expired one-off) and **M8** (stale detail sheet) — the two user-visible correctness bugs.
5. **M11 + M14** — CI drift-check and README status; ten minutes, keeps the repo honest.
6. Fold M1–M3 (lens semantics) into the deferred Phase-4 dial work, and M10 into the Phase-8 i18n pass — but stop adding new hardcoded strings now.
