# TimeZoneBar

A menu bar app for comparing times across cities and standard time zones. Every entry gets
a slider covering its own local day; drag any one of them and all the others follow, so you
can find an hour that works everywhere. The first row is always your local timezone.

**Requires macOS 26 (Tahoe).**

## Build and run

```bash
./build.sh --run
```

That produces `TimeZoneBar.app` next to this file and launches it. Look for the globe in
the menu bar — there's no Dock icon or app window.

| Command | What it does |
| --- | --- |
| `./build.sh` | Build only |
| `./build.sh --run` | Build, then relaunch from this folder |
| `./build.sh --install` | Build, copy to `/Applications`, relaunch from there |

Use `--install` if you turn on **Open at login**, so the app isn't launching from your
Desktop every morning.

## Using it

**First launch** starts with nothing but your local row, and opens the picker straight away
so the first thing you do is choose what to compare against. Everything you add is saved
immediately and comes back on the next launch — including the order you put rows in.

**The sliders.** Each row's track spans that city's own local day, 00:00 on the left to
24:00 on the right. Drag any slider and every other row moves to the same instant. The
shading tells you at a glance whether an hour is reasonable there:

| | |
| --- | --- |
| green | 09:00–18:00, working hours |
| orange | 07:00–09:00 and 18:00–22:00, awake but off the clock |
| grey | 22:00–07:00, asleep |

**Header controls.** `‹` `›` step an hour, `«` `»` step a day, **Now** snaps back to the
live clock.

**Adding entries.** *Add city*, then search. Results are split into **Standard time zones**
(`UTC`, `ET`, `CET`, `JST`, and so on — daylight saving is handled for you) and **Cities**
(hundreds of entries, searchable by name or alias). Enter adds the top hit; the field stays
focused so you can add several in a row.

**Removing a row.** Hover a row and a small × appears at its right edge. The local row has
no ×.

**Other per-row actions.** Right-click any row to rename it, add or edit a note (e.g. "Client
X" — useful for remembering who's in which city), move it up or down, copy its time as text,
or remove it. The local row can be renamed and noted but not removed or reordered.

**Settings** (gear icon): drag snap increment, 12/24-hour clock, whether the menu bar shows
the time, Open at login, *Check for Updates…*, and *Remove all cities* to get back to the
empty state.

## Updates

The app checks for updates automatically and shows a native update prompt when one's
available. You can also check manually from Settings → *Check for Updates…*.
