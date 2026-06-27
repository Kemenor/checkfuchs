# UI examples — visual canon

Static, self-contained HTML mockups of Checkfuchs's core surfaces, built against
[`../../DESIGN_SYSTEM.md`](../../DESIGN_SYSTEM.md). **These are the visual reference** until
the Flutter widgets exist; §4 of the design system points back here.

Open any file in a browser — each has a **light/dark toggle** (top-right). Fonts (Figtree,
Material Symbols) stream from Google Fonts, so an internet connection is needed to view them
as intended.

| File | Surface |
|---|---|
| `01-palette.html` | Triadic colour + status palette ("no alarm red") |
| `02-typography.html` | The four-font picker (Figtree default + accessibility faces) |
| `03-spacing-shape.html` | Radius/spacing scales, elevation, composed screen |
| `04-lens-view.html` | Home — carded lenses, View tabs, `statusFilter` (open-only vs full) |
| `05-task-detail.html` | Task detail sheet + row swipe actions (Done/Skip/Pass) |
| `06-recurrence.html` | Recurrence editor (weekly / monthly), live summary |

> These are throwaway HTML for *design decisions*, not production code. When a widget is
> built, conform it to the relevant file and add a `file:line` pointer in the design system.
