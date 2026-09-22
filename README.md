# TimeZoneBar

A menu bar app for comparing times across cities and standard time zones. Every entry gets
a slider covering its own local day; drag any one of them and all the others follow, so you
can find an hour that works everywhere. The first row is always your local timezone.

Built as a personal tool — no signing identity, no notarisation, no distribution.

**Requires macOS 26 (Tahoe)** — the UI uses Liquid Glass (`glassEffect`,
`GlassEffectContainer`, `.buttonStyle(.glass)`), which is macOS 26.0+ only.

## Build and run

```bash
./build.sh --run
```

That produces `TimeZoneBar.app` next to this file and launches it. Look for the globe in
the menu bar — there's no Dock icon or app window (`LSUIElement`).

Other modes:

| Command | What it does |
| --- | --- |
| `./build.sh` | Build only |
| `./build.sh --run` | Build, then relaunch from this folder |
| `./build.sh --install` | Build, copy to `/Applications`, relaunch from there |
| `./makeicon.sh` | Regenerate `Resources/AppIcon.icns` (only when the artwork changes) |
| `./preview.sh <dir>` | Run the checks and render the UI to PNGs |

Xcode isn't required — it compiles with `swiftc` from the Command Line Tools. If a copy of
Xcode is selected whose licence hasn't been accepted, the script falls back to the
Command Line Tools toolchain automatically.

Use `--install` if you turn on **Open at login**, so the app isn't launching from your
Desktop every morning.

## Using it

**First launch** starts with nothing but your local row, and opens the picker straight away
so the first thing you do is choose what to compare against. Everything you add is written to
preferences immediately and comes back on the next launch — including the order you put rows
in. The picker also reopens automatically any time the list is empty.

**Zone labels.** Each row shows its zone abbreviation next to the city name — `Amsterdam CET`,
`New York ET`, `Tokyo JST`. Rows added from the standard-zones section skip it, since their name
*is* the abbreviation. These are the **generic** forms (ET rather than EST/EDT, CET rather than
CET/CEST): that's what people actually write, and it stays correct when you scrub across a
daylight saving boundary.

They don't come from Foundation. `TimeZone.abbreviation()` is unusable here — under a European
locale it returns `GMT-5` for New York and `GMT+9` for Tokyo, giving real names only to European
zones. So abbreviations come from the standards table, and cities inherit one when their winter
and summer offsets fingerprint-match exactly one standard zone: Berlin picks up CET from Paris,
Toronto picks up ET from New York. Where a fingerprint is shared by two standards — London and
Lisbon are both (0, +1h) but are BST and WET — it's treated as ambiguous and left blank rather
than guessed at, with the handful of well-known exceptions pinned by hand. 328 of the 592 cities
resolve a label; the rest are zones with no commonly used abbreviation, and simply show none
rather than repeating the offset badge as `GMT+7`.

**The sliders.** Each row's track spans that city's own local day, 00:00 on the left to
24:00 on the right. Drag any slider and every other row moves to the same instant. The
shading tells you at a glance whether an hour is reasonable there:

| | |
| --- | --- |
| green | 09:00–18:00, working hours |
| orange | 07:00–09:00 and 18:00–22:00, awake but off the clock |
| grey | 22:00–07:00, asleep |

The time itself is coloured the same way. A thin vertical line on each track marks where
*now* actually is once you've scrubbed away from it.

**Header controls.** `‹` `›` step an hour, `«` `»` step a day, **Now** snaps back to the
live clock. The dot under the date is green while tracking the current time and orange
while you're scrubbing, with the offset shown next to it.

**Adding entries.** *Add city*, then search. Results come in two sections and
**standard time zones are always pinned above cities**:

- **Standard time zones** — 43 named abbreviations: `UTC`, `GMT`, `ET`, `CT`, `MT`, `PT`,
  `CET`, `BST`, `IST`, `JST`, `AEST`, `SAST`, `BRT` and so on. Each maps to a geographic
  zone, so daylight saving is handled for you — add `ET` and it reads EST in January and
  EDT in July. The seasonal spellings are searchable too: typing `EDT`, `PST` or `CEST`
  finds the right entry. Added rows are labelled with the abbreviation itself, so the list
  reads `ET`, `PT`, `JST`.
- **Cities** — 592 entries covering every zone in the system database, plus aliases so
  "Bengaluru", "Silicon Valley" or "Tel Aviv" find the right one.

Ambiguous abbreviations return every sensible match rather than guessing: `CST` offers both
US Central and China Standard Time, `IST` offers both India and Israel. When the box is
empty the twelve most common standard zones are shown; typing reaches all 43.

Enter adds the top hit (preferring the standard section); the field stays focused so you can
add several in a row. There's no limit on how many you keep.

**Removing a row.** Hover a row and a small × appears at its right edge — click it and the row
goes. Its slot is reserved even when hidden, so times stay aligned and nothing shifts as the ×
fades in, and the button is only clickable while visible so a click can't land on an invisible
target. The local row has no ×.

**Other per-row actions.** Right-click any row to rename it, move it up or down, copy its time
as text, or remove it. The local row can be renamed but not removed or reordered — it's
always first, and it re-reads your timezone if you travel.

**Settings** (gear icon): drag snap increment (1m–1h), 12/24-hour clock, whether the menu
bar shows the time next to the globe, Open at login, and *Remove all cities* to get back to
the empty state.

Your cities and preferences live in `UserDefaults` under `com.maxblaauw.timezonebar`, so
they survive rebuilds.

## Design

The UI follows Apple's Liquid Glass guidance, which is mostly about restraint: glass belongs
to the **control layer**, not the content layer.

- Glass is applied to the things you act on — the stepper cluster, *Now*, the footer buttons,
  the search field, the status pill, the slider handle. Rows, tracks and text stay plain so
  they remain legible.
- `GlassEffectContainer` wraps the stepper cluster and the footer so adjacent glass elements
  blend into one another instead of stacking into mush.
- One prominent action per group: *Now* turns prominent only while you're scrubbing, *Add
  city* while the picker is closed.
- The slider handle is `.regular.interactive()`, so it responds to touch the way system
  controls do, and it springs 14% larger while dragged.
- Shapes are concentric — a shared `Metrics.cardRadius` for row cards and panes, a tighter
  `trackRadius` nested inside them.
- Small text is never placed on glass. The offset and `LOCAL` chips are tinted capsules.
- Numerals use the rounded design with `.monospacedDigit()` and `.contentTransition(.numericText())`,
  so times tick over without the row width jittering.

Track shading is a soft-stopped gradient rather than hard rectangles, with a full-height
convex sheen (bright top, faintly shaded bottom) for depth.

**The scroll area needs a definite height, not just a maximum.** A `ScrollView` with only
`.frame(maxHeight:)` has no *ideal* height, and inside a `MenuBarExtra` window — which sizes
itself to fit its content — that resolves to zero: the panel opens with the rows collapsed and
only fills in once something else forces a resize, like toggling a pane. So the row stack
reports its height via `onGeometryChange` and the scroll view is framed at
`min(measured, 440)`. `RowMetrics` supplies a non-zero estimate for the very first frame,
before any measurement exists, and `preview.sh` asserts that estimate stays within 12% of what
the rows actually measure so it can't drift as the row design changes.

**No `GlassEffectContainer` anywhere, deliberately.** A container blends glass elements that
sit closer together than its `spacing`, and with 7pt gaps that turned the prominent *Now*
capsule into a blob with lobes reaching toward the chevrons either side of it. Containers are
for marks that *should* merge; nothing in this panel should.

### Icon

One `GlobeMark` shape — outer circle, meridian ellipse, latitude lines — serves both the app
icon and the menu bar, so they can't drift apart. It's generated, not hand-drawn:

```bash
./makeicon.sh
```

That renders `AppIconView` at all ten iconset sizes and runs `iconutil`, writing
`Resources/AppIcon.icns` plus a 512px preview. `build.sh` just copies the committed `.icns`,
so normal builds stay fast. Only rerun it when the artwork changes.

Each size is rendered natively rather than downscaled from one large image, and the mark sheds
detail as it shrinks — every stroke costs about a pixel of clearance, so at 16px it drops to
circle-plus-equator with a thicker relative stroke. Drawing the full globe at that size fills
in and reads as a solid ring.

The menu bar uses a real template `NSImage` built from the same path rather than a SwiftUI
shape, because template images are drawn from their alpha channel — that's what lets macOS
tint them for light and dark menu bars and invert them while the menu is open. A filled dot
is added bottom-right while you're scrubbing away from the live clock.

## Layout

```
Sources/TimeZoneBar/
  TimeZoneBarApp.swift   @main, the MenuBarExtra scene and its menu bar label
  Model.swift            City, AppStore (shared instant, persistence, formatting), HourClass
  CityCatalog.swift      standard zone abbreviations + searchable city list from the tz database
  Glass.swift            Liquid Glass helpers and shared metrics
  PanelView.swift        the popover: header, rows, settings, footer
  CityRowView.swift      one row — name, offset chip, time, track
  TimeTrack.swift        the custom day scrubber
  AddCityView.swift      search field and the two-section results list
Tools/main.swift         dev-only: logic checks + offscreen PNG renders (not in the bundle)
```

## Dev helper

```bash
./preview.sh /tmp/out
```

Runs assertions over the fiddly parts — 23- and 25-hour DST days, midnight crossings,
half- and quarter-hour offsets like Kolkata's +3:30 and Kathmandu's +3:45, snapping, standard
zone ranking and DST behaviour, catalog validity — and renders the views to PNGs so layout
can be checked without opening the menu bar.

`ImageRenderer` limitations to know about when reading those PNGs: it can't rasterize
`ScrollView` contents (blank), AppKit-backed controls like segmented pickers and checkboxes
(yellow placeholders), or live Liquid Glass. The tool renders scroll contents separately as
plain stacks, and sets `Appearance.flattenGlass` so glass surfaces show as a flat translucent
fill — layout is faithful, the material is not. The app itself never sets that flag.

## Notes

The ad-hoc signature (`codesign --sign -`) gives the bundle a stable identity, which
`SMAppService` needs for Open at login. Ad-hoc signatures are tied to the exact binary, so
Open at login may need re-toggling after a rebuild if macOS stops recognising the app.

**Why the build stages through a temp directory.** This folder sits on an iCloud-synced
Desktop. The file provider stamps `com.apple.FinderInfo` onto the `.app` as soon as it appears,
`codesign` refuses to sign a bundle carrying it, and `xattr -c` can't strip it (it's
provider-managed). So the bundle is assembled and signed in `mktemp -d` and only then copied
here — which is also why `--install` copies the staged bundle rather than this one.
