// Dev helper: renders the city rows offscreen to a PNG so the layout can be checked
// without opening the menu bar, and verifies every SF Symbol name the app uses.
// Not part of the app bundle.  Run via ./preview.sh
import AppKit
import SwiftUI

// Keep in sync with the systemName/systemImage literals in Sources/.
let symbols = [
    "globe", "globe.badge.chevron.backward",
    "chevron.left", "chevron.right", "chevron.left.2", "chevron.right.2",
    "plus", "checkmark", "gearshape", "power",
    "magnifyingglass", "xmark.circle.fill",
]

func checkSymbols() {
    var missing: [String] = []
    for s in symbols where NSImage(systemSymbolName: s, accessibilityDescription: nil) == nil {
        missing.append(s)
    }
    if missing.isEmpty {
        print("✓ all \(symbols.count) SF Symbols resolve")
    } else {
        print("✗ missing SF Symbols: \(missing.joined(separator: ", "))")
    }
}

@MainActor
func makeStore(scrubbed: Bool) -> AppStore {
    let store = AppStore()
    store.cities = [
        City(name: "New York", timeZoneID: "America/New_York"),
        City(name: "San Francisco", timeZoneID: "America/Los_Angeles"),
        City(name: "Bengaluru", timeZoneID: "Asia/Kolkata"),
        City(name: "Tokyo", timeZoneID: "Asia/Tokyo"),
        City(name: "Sydney", timeZoneID: "Australia/Sydney"),
    ]
    if scrubbed { store.setReference(store.now.addingTimeInterval(5 * 3600)) }
    return store
}

@MainActor
func render(_ scheme: ColorScheme, scrubbed: Bool, to path: String) {
    let store = makeStore(scrubbed: scrubbed)
    // Mirrors PanelView's row stack.
    let rows = VStack(alignment: .leading, spacing: 3) {
        CityRowView(city: store.localCity, isLocal: true).environmentObject(store)
        ForEach(store.cities) { c in
            CityRowView(city: c, isLocal: false).environmentObject(store)
        }
    }
    .padding(.horizontal, Metrics.gutter - 3)
    .padding(.vertical, 6)
    .frame(width: Metrics.panelWidth)
    .environmentObject(store)
    .environment(\.colorScheme, scheme)
    .background(scheme == .dark ? Color(white: 0.14) : Color(white: 0.97))

    let renderer = ImageRenderer(content: rows)
    renderer.scale = 2
    guard let img = renderer.nsImage,
          let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("render failed for \(scheme)")
        return
    }
    try? png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)  \(Int(img.size.width))x\(Int(img.size.height))pt")
}

@MainActor
func renderAny<V: View>(_ view: V, _ scheme: ColorScheme, to path: String) {
    let wrapped = view
        .frame(width: Metrics.panelWidth)
        .environment(\.colorScheme, scheme)
        .background(scheme == .dark ? Color(white: 0.14) : Color(white: 0.97))
    let renderer = ImageRenderer(content: wrapped)
    renderer.scale = 2
    guard let img = renderer.nsImage,
          let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("render failed for \(path)")
        return
    }
    try? png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)  \(Int(img.size.width))x\(Int(img.size.height))pt")
}

// MARK: - App icon generation

/// Renders each iconset size natively rather than downscaling one big image, so small
/// sizes keep crisp strokes.
@MainActor
func generateIconset(into dir: String) -> Bool {
    let sizes: [(pt: Int, scale: Int)] = [
        (16, 1), (16, 2), (32, 1), (32, 2), (128, 1),
        (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
    ]
    let fm = FileManager.default
    try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

    for (pt, scale) in sizes {
        let px = CGFloat(pt * scale)
        let renderer = ImageRenderer(content: AppIconView(size: px))
        renderer.scale = 1
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("✗ icon render failed at \(Int(px))px")
            return false
        }
        let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
        do {
            try png.write(to: URL(fileURLWithPath: "\(dir)/\(name)"))
        } catch {
            print("✗ couldn't write \(name): \(error.localizedDescription)")
            return false
        }
    }
    print("✓ rendered \(sizes.count) icon sizes into \(dir)")
    return true
}

// MARK: - Logic checks

var failures = 0
func expect(_ ok: Bool, _ what: String, _ detail: String = "") {
    if ok { print("   ✓ \(what)") } else { failures += 1; print("   ✗ \(what) \(detail)") }
}

/// Measures the real height of a rendered view.
@MainActor
func measuredHeight<V: View>(_ view: V) -> CGFloat {
    let renderer = ImageRenderer(content: view.frame(width: Metrics.panelWidth))
    renderer.scale = 1
    return renderer.nsImage?.size.height ?? 0
}

/// `RowMetrics` only feeds the scroll area's first-frame height, but if it drifts far from
/// reality the panel opens visibly wrong-sized, so keep it honest.
@MainActor
func runRowMetricsChecks() {
    print("row height estimates:")

    func rowsStack(cityCount: Int) -> some View {
        let store = AppStore(defaults: UserDefaults(suiteName: "com.maxblaauw.timezonebar.devrows")!)
        store.removeAll()
        for i in 0..<cityCount {
            store.add(CityCatalog.standardEntries[i % CityCatalog.standardEntries.count])
        }
        return VStack(alignment: .leading, spacing: RowMetrics.spacing) {
            CityRowView(city: store.localCity, isLocal: true).environmentObject(store)
            if store.cities.isEmpty {
                EmptyRowsHint()
            } else {
                ForEach(store.cities) { c in
                    CityRowView(city: c, isLocal: false).environmentObject(store)
                }
            }
        }
        .padding(.horizontal, Metrics.gutter - 3)
        .padding(.bottom, RowMetrics.bottomPadding)
        .environmentObject(store)
    }

    for count in [0, 1, 3, 6] {
        let actual = measuredHeight(rowsStack(cityCount: count))
        let estimate = RowMetrics.estimatedHeight(cityCount: count)
        let drift = abs(actual - estimate) / max(actual, 1)
        expect(drift < 0.12,
               String(format: "%d cities: estimate %.0f vs actual %.0f (%.0f%% off)",
                      count, estimate, actual, drift * 100))
    }
    expect(RowMetrics.estimatedHeight(cityCount: 0) > 0, "estimate is never zero")
    UserDefaults.standard.removePersistentDomain(forName: "com.maxblaauw.timezonebar.devrows")
}

/// Startup state and persistence, run against a throwaway defaults suite so the real
/// preferences are never touched.
@MainActor
func runPersistenceChecks() {
    print("startup / persistence checks:")
    let suiteName = "com.maxblaauw.timezonebar.devtests"
    guard let suite = UserDefaults(suiteName: suiteName) else {
        failures += 1
        print("   ✗ couldn't open test defaults suite")
        return
    }
    suite.removePersistentDomain(forName: suiteName)

    let fresh = AppStore(defaults: suite)
    expect(fresh.cities.isEmpty, "first launch has no cities", "got \(fresh.cities.count)")
    expect(fresh.allRows.count == 1, "only the local row is shown on first launch")

    guard let et = CityCatalog.standardEntries.first(where: { $0.display == "ET" }),
          let tokyo = CityCatalog.search("tokyo").cities.first else {
        failures += 1
        print("   ✗ fixtures missing from catalog")
        return
    }
    fresh.add(et)
    fresh.add(tokyo)
    expect(fresh.cities.count == 2, "two entries added")

    // A second store reads the same suite — this is what a relaunch does.
    let relaunched = AppStore(defaults: suite)
    expect(relaunched.cities.count == 2, "entries survive a restart",
           "got \(relaunched.cities.count)")
    expect(relaunched.cities.first?.name == "ET"
           && relaunched.cities.first?.timeZoneID == "America/New_York",
           "ET restored with its zone")
    expect(relaunched.cities.last?.name == "Tokyo", "Tokyo restored")
    expect(relaunched.allRows.first?.timeZoneID == TimeZone.current.identifier,
           "local row is still first after a restart")

    // Order is part of what gets saved.
    relaunched.move(relaunched.cities[1], by: -1)
    expect(AppStore(defaults: suite).cities.first?.name == "Tokyo", "reordering persists")

    relaunched.removeAll()
    expect(AppStore(defaults: suite).cities.isEmpty, "remove-all persists as empty")

    suite.removePersistentDomain(forName: suiteName)
}

@MainActor
func runChecks() {
    print("logic checks:")
    let store = AppStore()
    store.localTimeZone = TimeZone(identifier: "Europe/Amsterdam")!
    store.snapMinutes = 15

    func iso(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)!
    }

    // A 23-hour day (spring forward) and a 25-hour day (fall back) in Amsterdam.
    store.isPinnedToNow = false
    store.reference = iso("2026-03-29T12:00:00Z")
    var b = store.dayBounds(for: store.localTimeZone)
    expect(b.span == 82_800, "spring-forward day is 23h", "got \(b.span / 3600)h")

    store.reference = iso("2026-10-25T12:00:00Z")
    b = store.dayBounds(for: store.localTimeZone)
    expect(b.span == 90_000, "fall-back day is 25h", "got \(b.span / 3600)h")

    // Scrubbing to the far right of a row's track lands on 23:59-ish of that day, not the next.
    store.reference = iso("2026-07-01T10:00:00Z")
    let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    let tb = store.dayBounds(for: tokyo)
    store.setReference(tb.start.addingTimeInterval(tb.span - 1))
    let hour = store.calendar(for: tokyo).component(.hour, from: store.reference)
    expect(hour == 0 || hour == 23, "far-right scrub stays at end of day", "hour=\(hour)")

    // Day offsets across the date line.
    store.reference = iso("2026-07-01T22:00:00Z") // 00:00 Jul 2 in Amsterdam
    expect(store.dayOffset(for: TimeZone(identifier: "America/Los_Angeles")!) == -1,
           "LA is a day behind at Amsterdam midnight",
           "got \(store.dayOffset(for: TimeZone(identifier: "America/Los_Angeles")!))")
    // Auckland runs Amsterdam +10h in July, so it flips over at 14:00 local.
    store.reference = iso("2026-07-01T11:00:00Z") // 13:00 Amsterdam, 23:00 Auckland
    expect(store.dayOffset(for: TimeZone(identifier: "Pacific/Auckland")!) == 0,
           "Auckland is same day at Amsterdam 13:00",
           "got \(store.dayOffset(for: TimeZone(identifier: "Pacific/Auckland")!))")
    store.reference = iso("2026-07-01T18:00:00Z") // 20:00 Amsterdam, 06:00 next day Auckland
    expect(store.dayOffset(for: TimeZone(identifier: "Pacific/Auckland")!) == 1,
           "Auckland is a day ahead at Amsterdam 20:00",
           "got \(store.dayOffset(for: TimeZone(identifier: "Pacific/Auckland")!))")

    // Snapping.
    store.setReference(iso("2026-07-01T10:07:00Z"))
    let m = store.calendar(for: .gmt).component(.minute, from: store.reference)
    expect(m % 15 == 0, "15m snap applied", "minute=\(m)")

    // Half-hour and 45-minute offsets.
    store.reference = iso("2026-07-01T10:00:00Z")
    expect(store.offsetLabel(for: TimeZone(identifier: "Asia/Kolkata")!) == "+3:30",
           "Kolkata reads +3:30 from Amsterdam",
           store.offsetLabel(for: TimeZone(identifier: "Asia/Kolkata")!))
    expect(store.offsetLabel(for: TimeZone(identifier: "Asia/Kathmandu")!) == "+3:45",
           "Kathmandu reads +3:45", store.offsetLabel(for: TimeZone(identifier: "Asia/Kathmandu")!))
    expect(store.offsetLabel(for: TimeZone(identifier: "America/New_York")!) == "−6h",
           "New York reads −6h", store.offsetLabel(for: TimeZone(identifier: "America/New_York")!))

    // Hour classification boundaries.
    expect(HourClass.of(hour: 8) == .fringe && HourClass.of(hour: 9) == .work
           && HourClass.of(hour: 17) == .work && HourClass.of(hour: 18) == .fringe
           && HourClass.of(hour: 22) == .night && HourClass.of(hour: 3) == .night,
           "hour classes at boundaries")

    // Row order: local always first.
    expect(store.allRows.first?.timeZoneID == store.localTimeZone.identifier,
           "first row is the local timezone")
}

let args = Array(CommandLine.arguments.dropFirst())

// `--icon <dir>` just writes the iconset; makeicon.sh calls iconutil on it.
if args.first == "--icon" {
    let dir = args.count > 1 ? args[1] : "AppIcon.iconset"
    MainActor.assumeIsolated {
        // Also drop a large preview PNG next to it so the artwork can be eyeballed.
        let renderer = ImageRenderer(content: AppIconView(size: 512))
        renderer.scale = 1
        if let img = renderer.nsImage, let tiff = img.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "\(dir)-preview.png"))
        }
        exit(generateIconset(into: dir) ? 0 : 1)
    }
}

let out = args.first ?? "."
MainActor.assumeIsolated {
    // ImageRenderer can't rasterize live Liquid Glass; substitute a flat fill so the
    // layout is still visible in these PNGs.
    Appearance.flattenGlass = true
    checkSymbols()

    // Catalog sanity: every entry must map to a real timezone.
    let bad = CityCatalog.everything.filter { TimeZone(identifier: $0.timeZoneID) == nil }
    expect(bad.isEmpty,
           "catalog: \(CityCatalog.standardEntries.count) standard + \(CityCatalog.all.count) cities, all zones valid",
           "invalid: \(bad.prefix(5).map(\.timeZoneID))")

    // Standard zones must be pinned above cities for every query that matches one.
    print("search results (standard section first):")
    for q in ["", "et", "gmt", "pt", "cst", "ist", "jst", "utc", "tokyo", "ams", "bengal"] {
        let r = CityCatalog.search(q)
        let std = r.standard.prefix(3).map { "\($0.display)→\($0.timeZoneID)" }
        let cty = r.cities.prefix(2).map(\.display)
        print("   “\(q)”  standard: [\(std.joined(separator: ", "))]  cities: [\(cty.joined(separator: ", "))]")
    }
    for q in ["et", "gmt", "pt", "jst", "utc"] {
        expect(!CityCatalog.search(q).standard.isEmpty, "“\(q)” finds a standard zone")
    }
    expect(CityCatalog.search("et").standard.first?.display == "ET", "“et” ranks ET first",
           CityCatalog.search("et").standard.first?.display ?? "nil")
    expect(CityCatalog.search("pt").standard.first?.timeZoneID == "America/Los_Angeles",
           "“pt” maps to Pacific Time")
    // CST is ambiguous: US Central and China both. Both should be reachable.
    let cst = CityCatalog.search("cst").standard.map(\.timeZoneID)
    expect(cst.contains("America/Chicago") && cst.contains("Asia/Shanghai"),
           "“cst” offers both US Central and China", "\(cst)")
    // Zone abbreviations shown on the rows.
    print("row abbreviations:")
    let abbrevCases: [(String, String?)] = [
        ("Europe/Amsterdam", "CET"), ("Europe/Berlin", "CET"), ("Europe/Madrid", "CET"),
        ("Europe/London", "BST"), ("Europe/Lisbon", "WET"),
        ("America/New_York", "ET"), ("America/Toronto", "ET"),
        ("America/Los_Angeles", "PT"), ("America/Vancouver", "PT"),
        ("America/Chicago", "CT"), ("America/Denver", "MT"),
        ("Asia/Tokyo", "JST"), ("Asia/Kolkata", "IST"), ("Asia/Kathmandu", "NPT"),
        ("Asia/Dubai", "GST"), ("Asia/Shanghai", "CST"), ("Australia/Sydney", "AEST"),
        ("Pacific/Auckland", "NZST"), ("Africa/Johannesburg", "SAST"),
        // Foundation normalises the "UTC" identifier to "GMT", so the two zones are
        // indistinguishable at runtime and both resolve to GMT. Rows named UTC or GMT hide
        // the label anyway — their name is already the abbreviation.
        ("America/Sao_Paulo", "BRT"), ("UTC", "GMT"), ("GMT", "GMT"),
    ]
    for (zone, want) in abbrevCases {
        guard let tz = TimeZone(identifier: zone) else { continue }
        let got = CityCatalog.abbreviation(for: tz)
        expect(got == want, "\(zone) → \(want ?? "nil")", "got \(got ?? "nil")")
    }
    // Never fall back to an offset placeholder — that just repeats the offset badge.
    let placeholders = CityCatalog.all.compactMap { e -> String? in
        guard let tz = TimeZone(identifier: e.timeZoneID),
              let a = CityCatalog.abbreviation(for: tz) else { return nil }
        return a.contains("+") || a.contains("-") ? "\(e.display)=\(a)" : nil
    }
    expect(placeholders.isEmpty, "no GMT±N placeholders leak through",
           "\(placeholders.prefix(4))")
    let covered = CityCatalog.all.filter {
        TimeZone(identifier: $0.timeZoneID).flatMap { CityCatalog.abbreviation(for: $0) } != nil
    }
    print("   \(covered.count)/\(CityCatalog.all.count) cities resolve an abbreviation")
    // Which of the well-known cities come up blank?
    let blankFeatured = CityCatalog.all.prefix(52).filter {
        TimeZone(identifier: $0.timeZoneID).flatMap { CityCatalog.abbreviation(for: $0) } == nil
    }
    print("   featured cities with no abbreviation: \(blankFeatured.map(\.display))")

    // Standard zones follow DST because they map to geographic zones.
    let etZone = TimeZone(identifier: "America/New_York")!
    let jan = ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")!
    let jul = ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z")!
    expect(etZone.secondsFromGMT(for: jan) != etZone.secondsFromGMT(for: jul),
           "ET shifts with daylight saving")

    runPersistenceChecks()
    runRowMetricsChecks()
    runChecks()

    render(.light, scrubbed: false, to: "\(out)/preview-light.png")
    render(.dark, scrubbed: false, to: "\(out)/preview-dark.png")
    render(.light, scrubbed: true, to: "\(out)/preview-scrubbed.png")

    let store = makeStore(scrubbed: false)

    // First-launch state: local row only, plus the hint.
    let emptyStore = AppStore(defaults: UserDefaults(suiteName: "com.maxblaauw.timezonebar.devempty")!)
    emptyStore.removeAll()
    let firstRun = VStack(alignment: .leading, spacing: 3) {
        CityRowView(city: emptyStore.localCity, isLocal: true).environmentObject(emptyStore)
        EmptyRowsHint()
    }
    .padding(.horizontal, Metrics.gutter - 3)
    .padding(.vertical, 6)
    renderAny(firstRun, .light, to: "\(out)/preview-firstrun.png")

    // The row × only shows on hover, which ImageRenderer can't simulate — render it forced
    // visible so its size and placement can be checked.
    let deleteDemo = HStack(spacing: 7) {
        Text("Tokyo").font(.system(size: 13, weight: .semibold))
        Spacer()
        Text("16:35").font(.system(size: 19, weight: .semibold, design: .rounded).monospacedDigit())
        Text("Wed").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            .frame(width: 44, alignment: .trailing)
        RowDeleteButton(visible: true, label: "Tokyo", action: {})
    }
    .padding(.horizontal, 11).padding(.vertical, 9)
    renderAny(deleteDemo, .light, to: "\(out)/preview-delete.png")

    renderAny(SettingsSection().environmentObject(store), .light, to: "\(out)/preview-settings.png")
    renderAny(AddCityView(isPresented: .constant(true)).environmentObject(store),
              .light, to: "\(out)/preview-add.png")

    // The results list lives in a ScrollView, which ImageRenderer can't rasterize,
    // so render the rows on their own to check their layout — both sections.
    let r = CityCatalog.search("")
    let list = VStack(alignment: .leading, spacing: 0) {
        sectionLabel("Standard time zones").padding(.horizontal, 7).padding(.bottom, 3)
        ForEach(Array(r.standard.prefix(6))) { e in
            ResultRow(entry: e, action: {}).environmentObject(store)
        }
        sectionLabel("Cities").padding(.horizontal, 7).padding(.top, 8).padding(.bottom, 3)
        ForEach(Array(r.cities.prefix(4))) { e in
            ResultRow(entry: e, action: {}).environmentObject(store)
        }
    }
    .padding(.horizontal, 12).padding(.vertical, 8)
    renderAny(list, .light, to: "\(out)/preview-results.png")
    renderAny(list, .dark, to: "\(out)/preview-results-dark.png")
    renderAny(PanelView().environmentObject(store), .light, to: "\(out)/preview-panel.png")

    print(failures == 0 ? "\nALL CHECKS PASSED" : "\n\(failures) CHECK(S) FAILED")
}
exit(failures == 0 ? 0 : 1)
