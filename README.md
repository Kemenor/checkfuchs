# Checkfuchs 🦊

A combined **habit & to-do** app for people who drop rigid systems. One surface for
both — because a daily habit you can't skip (brushing your teeth) is what keeps you
opening the app, and that daily glance keeps everything *else* visible too. Your data
stays on your phone.

> Built because habit apps and to-do apps split one mental object in two — and pure
> to-do apps die the moment you have a full day and nothing gets ticked off.

🌐 [checkfuchs.fuchsnest.ch](https://checkfuchs.fuchsnest.ch)

## The idea

- 🪥 **Habits carry the app.** As long as one unavoidable daily habit exists, you open
  Checkfuchs every day — and your dated tasks and backlog ride along, never silently
  vanishing.
- 🧘 **"Not done" is data, not a verdict.** A missed habit just *fades* — it never nags or
  bleeds red. The only real failure is a hard deadline you let pass.
- 🔭 **Lenses & Views — look at your tasks your way.** A *Lens* picks and orders a slice of
  your tasks (all your daily habits; one weekly chore to chip at; the next due dates). A
  *View* arranges the Lenses you care about into a screen — a calm **Home**, a detailed
  **Habits** tracker, a **Long-term** backlog. Not rigid categories; dials you set.
- 🔁 **Habits and to-dos are one object.** A one-off becomes a series in two taps;
  "every other Saturday" and "the 25th of each month" are easy; editing *this* occurrence
  vs. *the whole series* works like a calendar — no surprises behind your back.
- 🕗 **Windows and reminders that fit real days.** A habit can be "morning *or* evening"
  (done once in either), with custom bands on top; reminders are the presets plus your
  own "2 days before at 18:00".
- 📊 **Stats you compose.** A Stats tab built from tiles you switch on and reorder —
  completion, this week, streaks, by window, habit grid, misses by weekday, one insight.
- 🎨 **Calm by design.** No ads, no subscription, no dark patterns. Dark + light, four
  languages, and a typeface picker that includes dyslexia- and low-vision-friendly fonts.

## Privacy

Fully on-device. No accounts, no analytics, no server, no ads, no subscription. Every
reminder is computed locally from your tasks — nothing ever leaves the phone.

## Stack

Flutter · drift (SQLite) · Riverpod · Material 3 · `flutter_local_notifications` +
`workmanager` · local-first, serverless. Four languages: English, German, French, Italian. Part of the
**[Fuchsbau](https://github.com/Kemenor/fuchsbau)** family — the shared ethos, design
system, and base stack behind the fox apps.

## Status

**Dogfoodable — the whole vertical works, plus a second design pass.** Phases 0–8 are
done: create (recurring or one-off) → complete/skip → edit or convert a series → Views &
Lenses → pause & vacation → streaks → reminders (device-verified, with a ~12 h
background refresh) → backup/restore → onboarding, all in four languages. The September
2026 pass added multi-lens tasks, the Night band, multi-band windows, custom reminders, a
customizable Stats tab, the lens editor in the library, an intro pager, and the adaptive
fox icon. Release (Phase 9: signing, fastlane) is still ahead. The model lives in
[`design-concept.md`](./design-concept.md), the look in
[`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md) (with HTML mockups in
[`examples/ui/`](./examples/ui/)), and the stack + phased roadmap in
[`PLAN.md`](./PLAN.md).

## Build & run

Dev toolchain lives in a distrobox container (`flutter`):

```sh
distrobox enter flutter -- bash -lc 'flutter test'
distrobox enter flutter -- bash -lc 'flutter run'
```

## License

[Apache-2.0](./LICENSE) — Copyright 2026 Kemenor.
