import AppKit
import Combine
import ServiceManagement
import SwiftUI

// MARK: - City

struct City: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var timeZoneID: String

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
}

// MARK: - Hour classification

enum HourClass {
    case night   // asleep
    case fringe  // early morning / evening
    case work    // core hours

    static func of(hour: Int) -> HourClass {
        switch hour {
        case 9..<18: return .work
        case 7..<9, 18..<22: return .fringe
        default: return .night
        }
    }

    func trackColor(_ scheme: ColorScheme) -> Color {
        let dark = scheme == .dark
        switch self {
        case .night:  // dusk blue rather than flat grey
            return dark ? Color(red: 0.34, green: 0.40, blue: 0.62).opacity(0.38)
                        : Color(red: 0.34, green: 0.42, blue: 0.68).opacity(0.24)
        case .fringe:
            return dark ? Color(red: 1.00, green: 0.70, blue: 0.26).opacity(0.40)
                        : Color(red: 1.00, green: 0.64, blue: 0.16).opacity(0.40)
        case .work:
            return dark ? Color(red: 0.30, green: 0.84, blue: 0.47).opacity(0.40)
                        : Color(red: 0.13, green: 0.72, blue: 0.38).opacity(0.38)
        }
    }

    var textColor: Color {
        switch self {
        case .night: return .secondary
        case .fringe: return .orange
        case .work: return .primary
        }
    }

    var label: String {
        switch self {
        case .night: return "asleep"
        case .fringe: return "early / late"
        case .work: return "working hours"
        }
    }
}

// MARK: - Store

@MainActor
final class AppStore: ObservableObject {
    /// Extra cities the user added. The local timezone is always shown first and is not part of this list.
    @Published var cities: [City] = [] { didSet { persistCities() } }

    /// The instant every slider is currently pointing at.
    @Published var reference: Date = Date()

    /// While true, `reference` follows the wall clock.
    @Published var isPinnedToNow: Bool = true

    /// The real current time, ticked every second.
    @Published var now: Date = Date()

    /// The local timezone, refreshed when macOS reports a change.
    @Published var localTimeZone: TimeZone = .current

    @Published var snapMinutes: Int {
        didSet { defaults.set(snapMinutes, forKey: Keys.snap) }
    }
    @Published var use24Hour: Bool {
        didSet { defaults.set(use24Hour, forKey: Keys.use24) }
    }
    @Published var showMenuBarTime: Bool {
        didSet { defaults.set(showMenuBarTime, forKey: Keys.menuBarTime) }
    }
    @Published var localName: String {
        didSet { defaults.set(localName, forKey: Keys.localName) }
    }

    private enum Keys {
        // v2: v1 was seeded with sample cities on first launch. Bumping the key retires
        // that seeded list once so the app starts genuinely empty.
        static let cities = "cities.v2"
        static let retiredCities = "cities.v1"
        static let snap = "snapMinutes"
        static let use24 = "use24Hour"
        static let menuBarTime = "showMenuBarTime"
        static let localName = "localName"
    }

    private let defaults: UserDefaults
    private var ticker: AnyCancellable?
    private var tzObserver: Any?

    /// `defaults` is injectable so the dev tool can exercise persistence against a throwaway
    /// suite instead of the real preferences.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let d = defaults
        snapMinutes = d.object(forKey: Keys.snap) as? Int ?? 15
        use24Hour = d.object(forKey: Keys.use24) as? Bool ?? true
        showMenuBarTime = d.object(forKey: Keys.menuBarTime) as? Bool ?? true
        localName = d.string(forKey: Keys.localName) ?? CityCatalog.defaultName(for: TimeZone.current.identifier)

        // Starts empty on a fresh install — the panel opens the picker so the first thing
        // you do is choose your cities. Anything you pick is saved from then on.
        if let data = d.data(forKey: Keys.cities),
           let decoded = try? JSONDecoder().decode([City].self, from: data) {
            cities = decoded
        } else {
            cities = []
        }

        // Retire the seeded v1 list rather than leaving it in preferences forever.
        d.removeObject(forKey: Keys.retiredCities)

        ticker = Timer.publish(every: 1, tolerance: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                guard let self else { return }
                self.now = date
                if self.isPinnedToNow { self.reference = date }
            }

        tzObserver = NotificationCenter.default
            .publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                NSTimeZone.resetSystemTimeZone()
                self?.localTimeZone = TimeZone.current
            }
    }

    // MARK: Rows

    /// Row 0 is always the local timezone.
    var localCity: City {
        City(id: Self.localRowID, name: localName, timeZoneID: localTimeZone.identifier)
    }

    static let localRowID = UUID(uuidString: "00000000-0000-0000-0000-0000000010CA")!

    var allRows: [City] { [localCity] + cities }

    // MARK: Mutations

    func add(_ entry: CatalogEntry) {
        cities.append(City(name: entry.display, timeZoneID: entry.timeZoneID))
    }

    func remove(_ city: City) {
        cities.removeAll { $0.id == city.id }
    }

    func removeAll() {
        cities.removeAll()
    }

    func rename(_ city: City, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if city.id == Self.localRowID {
            localName = trimmed
            return
        }
        guard let idx = cities.firstIndex(where: { $0.id == city.id }) else { return }
        cities[idx].name = trimmed
    }

    func move(_ city: City, by offset: Int) {
        guard let idx = cities.firstIndex(where: { $0.id == city.id }) else { return }
        let target = idx + offset
        guard cities.indices.contains(target) else { return }
        cities.swapAt(idx, target)
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        cities.move(fromOffsets: source, toOffset: destination)
    }

    func resetToNow() {
        isPinnedToNow = true
        reference = Date()
    }

    /// Sets the shared instant, snapping to the configured increment.
    func setReference(_ date: Date) {
        isPinnedToNow = false
        reference = snap(date)
    }

    func nudge(hours: Int) {
        setReference(reference.addingTimeInterval(Double(hours) * 3600))
    }

    func nudge(minutes: Int) {
        isPinnedToNow = false
        reference = reference.addingTimeInterval(Double(minutes) * 60)
    }

    private func snap(_ date: Date) -> Date {
        let step = Double(max(1, snapMinutes)) * 60
        return Date(timeIntervalSinceReferenceDate:
            (date.timeIntervalSinceReferenceDate / step).rounded() * step)
    }

    private func persistCities() {
        if let data = try? JSONEncoder().encode(cities) {
            defaults.set(data, forKey: Keys.cities)
        }
    }

    // MARK: Formatting helpers

    func calendar(for tz: TimeZone) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal
    }

    /// Start and end of the local day (in `tz`) that contains `reference`. DST-aware.
    func dayBounds(for tz: TimeZone) -> (start: Date, span: Double) {
        let cal = calendar(for: tz)
        let start = cal.startOfDay(for: reference)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return (start, end.timeIntervalSince(start))
    }

    func timeString(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate(use24Hour ? "HHmm" : "hmm")
        return f.string(from: date)
    }

    func shortDayString(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f.string(from: date)
    }

    func weekdayString(_ date: Date, tz: TimeZone) -> String {
        let f = DateFormatter()
        f.timeZone = tz
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f.string(from: date)
    }

    /// "+9h", "−3:30" or "" when identical to local.
    func offsetLabel(for tz: TimeZone) -> String {
        let delta = tz.secondsFromGMT(for: reference) - localTimeZone.secondsFromGMT(for: reference)
        if delta == 0 { return "same" }
        let sign = delta < 0 ? "−" : "+"
        let mins = abs(delta) / 60
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(sign)\(h)h" : String(format: "%@%d:%02d", sign, h, m)
    }

    /// Day difference against the local day, e.g. -1, 0, +1.
    func dayOffset(for tz: TimeZone) -> Int {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let mine = calendar(for: localTimeZone).dateComponents([.year, .month, .day], from: reference)
        let theirs = calendar(for: tz).dateComponents([.year, .month, .day], from: reference)
        guard let a = utc.date(from: mine), let b = utc.date(from: theirs) else { return 0 }
        return utc.dateComponents([.day], from: a, to: b).day ?? 0
    }

    func hourClass(at date: Date, tz: TimeZone) -> HourClass {
        HourClass.of(hour: calendar(for: tz).component(.hour, from: date))
    }

    var isScrubbed: Bool {
        !isPinnedToNow && abs(reference.timeIntervalSince(now)) > 60
    }

    /// Signed difference between the viewed instant and now, as a short human label.
    var scrubLabel: String {
        let delta = reference.timeIntervalSince(now)
        let mins = Int((abs(delta) / 60).rounded())
        let sign = delta < 0 ? "−" : "+"
        if mins < 60 { return "\(sign)\(mins)m" }
        let h = mins / 60, m = mins % 60
        return m == 0 ? "\(sign)\(h)h" : "\(sign)\(h)h \(m)m"
    }

    // MARK: Launch at login

    var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
