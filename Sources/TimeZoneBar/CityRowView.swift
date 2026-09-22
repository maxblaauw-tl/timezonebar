import SwiftUI

struct CityRowView: View {
    @EnvironmentObject var store: AppStore
    let city: City
    let isLocal: Bool

    @State private var isRenaming = false
    @State private var draftName = ""
    @State private var hovering = false
    @FocusState private var renameFocused: Bool

    private var tz: TimeZone { city.timeZone }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            topLine
            TimeTrack(
                dayStart: bounds.start,
                span: bounds.span,
                value: store.reference.timeIntervalSince(bounds.start),
                nowValue: nowValue,
                hourClasses: hourClasses,
                showScale: isLocal,
                onScrub: { store.setReference(bounds.start.addingTimeInterval($0)) }
            )
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background {
            let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
            if isLocal {
                shape.fill(Color.accentColor.opacity(0.09))
                    .overlay(shape.stroke(Color.accentColor.opacity(0.16), lineWidth: 0.5))
            } else if hovering {
                shape.fill(Color.primary.opacity(0.045))
            }
        }
        .contentShape(Rectangle())
        .onHover { h in withAnimation(.smooth(duration: 0.15)) { hovering = h } }
        .contextMenu { menu }
    }

    // MARK: Top line

    private var topLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if isRenaming {
                TextField("Name", text: $draftName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .focused($renameFocused)
                    .onSubmit { commitRename() }
                    .onExitCommand { isRenaming = false }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .glassBackground(in: Capsule())
                    .frame(maxWidth: 170)
                Button("Done") { commitRename() }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            } else {
                Text(city.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                if !CityCatalog.isAbbreviationName(city.name) {
                    Text(CityCatalog.country(forName: city.name, timeZoneID: city.timeZoneID))
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                // The zone's own name — ET, PT, CET. Quiet text rather than a second capsule,
                // so the row doesn't turn into a row of badges. Skipped when the row is named
                // after an abbreviation already (a row added from the standard-zones section),
                // and for the handful of zones with no recognised one.
                if !CityCatalog.isAbbreviationName(city.name),
                   let abbr = CityCatalog.abbreviation(for: tz) {
                    Text(abbr)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.3)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                if isLocal {
                    chip("LOCAL", tint: .accentColor)
                } else {
                    chip(store.offsetLabel(for: tz), tint: nil)
                }
            }

            Spacer(minLength: 4)

            Text(store.timeString(store.reference, tz: tz))
                .font(.system(size: 19, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(store.hourClass(at: store.reference, tz: tz).textColor)
                .contentTransition(.numericText())
                .animation(.smooth(duration: 0.2), value: store.reference)

            Text(dayLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)

            // The slot is always reserved — including on the local row, which has no button —
            // so times stay aligned and nothing shifts when the × fades in.
            RowDeleteButton(visible: hovering && !isLocal && !isRenaming,
                            label: city.name) {
                withAnimation(.smooth(duration: 0.2)) { store.remove(city) }
            }
        }
    }

    private func chip(_ text: String, tint: Color?) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold).monospacedDigit())
            .foregroundStyle(tint ?? .secondary)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background((tint ?? Color.secondary).opacity(tint == nil ? 0.13 : 0.16), in: Capsule())
    }

    // MARK: Context menu

    @ViewBuilder
    private var menu: some View {
        Button("Rename…") {
            draftName = city.name
            isRenaming = true
            DispatchQueue.main.async { renameFocused = true }
        }
        Button("Copy Time") {
            let text = "\(city.name) — \(store.timeString(store.reference, tz: tz)) \(store.weekdayString(store.reference, tz: tz))"
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        if !isLocal {
            Divider()
            Button("Move Up") { store.move(city, by: -1) }
            Button("Move Down") { store.move(city, by: 1) }
            Divider()
            Button("Remove", role: .destructive) { store.remove(city) }
        }
        Divider()
        Text(city.timeZoneID)
    }

    private func commitRename() {
        store.rename(city, to: draftName)
        isRenaming = false
    }

    // MARK: Derived

    private var bounds: (start: Date, span: Double) { store.dayBounds(for: tz) }

    private var nowValue: Double? {
        let v = store.now.timeIntervalSince(bounds.start)
        return (v >= 0 && v <= bounds.span) ? v : nil
    }

    private var hourClasses: [HourClass] {
        let cal = store.calendar(for: tz)
        let buckets = Int((bounds.span / 3600).rounded())
        return (0..<max(buckets, 1)).map { i in
            HourClass.of(hour: cal.component(.hour,
                from: bounds.start.addingTimeInterval(Double(i) * 3600 + 60)))
        }
    }

    private var dayLabel: String {
        let delta = store.dayOffset(for: tz)
        let weekday = store.shortDayString(store.reference, tz: tz)
        if delta == 0 { return weekday }
        return "\(weekday) \(delta > 0 ? "+" : "−")\(abs(delta))"
    }
}

/// The remove affordance on a row. Occupies its slot whether or not it's showing, and is
/// only clickable while visible so a click can't land on an invisible button.
struct RowDeleteButton: View {
    let visible: Bool
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 12))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(hovering ? Color.red : Color.secondary)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.smooth(duration: 0.12)) { hovering = h } }
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
        .help("Remove \(label)")
        .accessibilityLabel("Remove \(label)")
        .frame(width: 16)
    }
}
