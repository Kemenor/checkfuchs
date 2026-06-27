# Checkfuchs 🦊

A combined **habit & to-do** app for people who drop rigid systems. One surface for
both — because a daily habit you can't skip (brushing your teeth) is what keeps you
opening the app, and that daily glance keeps everything *else* visible too. Your data
stays on your phone.

> Built because habit apps and to-do apps split one mental object in two — and pure
> to-do apps die the moment you have a full day and nothing gets ticked off.

🌐 [checkfuchs.ch](https://checkfuchs.ch)

## The idea

- 🪥 **Habits carry the app.** As long as one unavoidable daily habit exists, you open
  Checkfuchs every day — and your dated tasks and backlog ride along, never silently
  vanishing.
- 🚦 **Three visibility tiers.** Daily habits are *always* shown; hard-dated items
  *announce themselves* as their day nears; the backlog waits *passively* until you visit.
- 🧘 **"Not done" is data, not a verdict.** A missed habit is tracked, never punished.
  The only real failure is a hard deadline that physically passes. Avoidance shows up as
  a colour shift — "you've pushed this 6 weeks" — never a nag.
- 🔁 **Habits and to-dos are one thing.** A one-off can become a series; a yearly task can
  live in your weekly list. Editing one occurrence vs. the whole series works like
  Outlook — no surprises behind your back.
- 🗂️ **Pools, not rigid categories.** Habits, hard dates, a weekly pool, a monthly pool,
  quick to-dos — all the same machine with a few dials turned. Build your own.

## Privacy

Fully on-device. No accounts, no analytics, no server, no ads, no subscription. Every
reminder is computed locally from your tasks — nothing ever leaves the phone.

## Stack

Flutter · drift (SQLite) · Riverpod · Material 3 · `flutter_local_notifications` ·
local-first, serverless. Four languages: English, German, French, Italian.

## Status

Early. The conceptual data model is frozen in [`design-concept.md`](./design-concept.md);
the stack, schema, and phased build order are in [`PLAN.md`](./PLAN.md).

## Build & run

Dev toolchain lives in a distrobox container (`flutter`):

```sh
distrobox enter flutter -- bash -lc 'flutter test'
distrobox enter flutter -- bash -lc 'flutter run'
```

## License

TBD
