import SwiftUI

struct PanelView: View {
    @EnvironmentObject var store: AppStore
    @State private var pane: Pane = .none
    @State private var measuredRowsHeight: CGFloat?

    enum Pane { case none, add, settings }

    private static let maxRowsHeight: CGFloat = 440

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    CityRowView(city: store.localCity, isLocal: true)
                        .environmentObject(store)
                    if store.cities.isEmpty {
                        EmptyRowsHint()
                    } else {
                        ForEach(store.cities) { city in
                            CityRowView(city: city, isLocal: false)
                                .environmentObject(store)
                        }
                    }
                }
                .padding(.horizontal, Metrics.gutter - 3)
                .padding(.bottom, 6)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                    if h > 0 { measuredRowsHeight = h }
                }
            }
            // A definite height, not just a maximum. `.frame(maxHeight:)` alone gives the
            // scroll view no ideal height, and inside a MenuBarExtra window — which sizes
            // itself to fit its content — that resolves to zero, so the panel opens with the
            // rows collapsed and only fills in once something else forces a resize.
            .frame(height: rowsHeight)
            .scrollBounceBehavior(.basedOnSize)

            if pane == .add {
                AddCityView(isPresented: Binding(
                    get: { pane == .add },
                    set: { pane = $0 ? .add : .none }
                ))
                .environmentObject(store)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if pane == .settings {
                SettingsSection()
                    .environmentObject(store)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            footer
        }
        .frame(width: Metrics.panelWidth)
        .animation(.smooth(duration: 0.26), value: pane)
        .onAppear {
            // Nothing to compare against yet, so go straight to picking.
            if store.cities.isEmpty { pane = .add }
        }
    }

    /// Height for the scroll area: the measured content height once we have it, capped.
    private var rowsHeight: CGFloat {
        min(measuredRowsHeight ?? estimatedRowsHeight, Self.maxRowsHeight)
    }

    /// Used only for the frame before the first layout pass reports a real height. It just
    /// has to be non-zero and roughly right; `onGeometryChange` corrects it immediately.
    private var estimatedRowsHeight: CGFloat {
        RowMetrics.estimatedHeight(cityCount: store.cities.count)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.timeString(store.reference, tz: store.localTimeZone))
                    .font(.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                    .fixedSize()
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.2), value: store.reference)
                Text(store.weekdayString(store.reference, tz: store.localTimeZone))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 7) {
                statusPill
                stepper
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(store.isPinnedToNow ? Color.green : Color.orange)
                .frame(width: 5, height: 5)
            Text(store.isPinnedToNow ? "Live" : store.scrubLabel)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .glassBackground(.clear, in: Capsule())
        .animation(.smooth(duration: 0.2), value: store.isPinnedToNow)
    }

    // No GlassEffectContainer here on purpose: a container makes glass elements closer
    // than its spacing blend into each other, which turns the prominent "Now" capsule
    // into a blob with lobes reaching towards the chevrons either side of it.
    private var stepper: some View {
        HStack(spacing: 7) {
            step("chevron.left.2", "Back one day") { store.nudge(hours: -24) }
            step("chevron.left", "Back one hour") { store.nudge(hours: -1) }
            Button { store.resetToNow() } label: {
                Text("Now").font(.system(size: 11, weight: .semibold))
            }
            .glassButton(prominent: !store.isPinnedToNow)
            .controlSize(.small)
            .disabled(store.isPinnedToNow)
            .help("Jump back to the current time")
            step("chevron.right", "Forward one hour") { store.nudge(hours: 1) }
            step("chevron.right.2", "Forward one day") { store.nudge(hours: 24) }
        }
    }

    private func step(_ icon: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
        }
        .glassButton()
        .controlSize(.small)
        .buttonBorderShape(.circle)
        .help(help)
    }

    // MARK: Footer

    // Also uncontained — same reason as `stepper`.
    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                pane = pane == .add ? .none : .add
            } label: {
                Label(pane == .add ? "Done" : "Add city",
                      systemImage: pane == .add ? "checkmark" : "plus")
                    .font(.system(size: 11, weight: .medium))
            }
            .glassButton(prominent: pane != .add)
            .controlSize(.small)

            Spacer()

            Button { pane = pane == .settings ? .none : .settings } label: {
                Image(systemName: "gearshape").font(.system(size: 11, weight: .medium))
            }
            .glassButton()
            .controlSize(.small)
            .buttonBorderShape(.circle)
            .help("Settings")

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power").font(.system(size: 11, weight: .medium))
            }
            .glassButton()
            .controlSize(.small)
            .buttonBorderShape(.circle)
            .help("Quit TimeZoneBar")
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }
}

/// Shown in place of the city rows on a fresh install, while the picker is open below.
struct EmptyRowsHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("No cities yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Search below to add cities, or standard zones like ET, GMT or JST. Whatever you pick is saved for next time.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 14)
    }
}

// MARK: - Settings

struct SettingsSection: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Settings")

            HStack(spacing: 8) {
                Text("Snap dragging to").font(.system(size: 11)).foregroundStyle(.secondary)
                Picker("", selection: $store.snapMinutes) {
                    Text("1m").tag(1)
                    Text("5m").tag(5)
                    Text("15m").tag(15)
                    Text("30m").tag(30)
                    Text("1h").tag(60)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 200)
            }

            Toggle("24-hour clock", isOn: $store.use24Hour)
                .font(.system(size: 11)).toggleStyle(.checkbox)
            Toggle("Show time in the menu bar", isOn: $store.showMenuBarTime)
                .font(.system(size: 11)).toggleStyle(.checkbox)
            LaunchAtLoginToggle().environmentObject(store)

            HStack(spacing: 12) {
                swatch(.work)
                swatch(.fringe)
                swatch(.night)
            }
            .padding(.top, 2)

            Text("Right-click a city to rename, reorder, copy its time or remove it.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            CheckForUpdatesButton()

            if !store.cities.isEmpty {
                Button("Remove all \(store.cities.count) cities") { store.removeAll() }
                    .font(.system(size: 10.5))
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.primary.opacity(0.035),
                    in: RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .padding(.horizontal, Metrics.gutter - 3)
        .padding(.bottom, 2)
    }

    private func swatch(_ cls: HourClass) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(cls.trackColor(scheme))
                .frame(width: 16, height: 9)
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 0.5))
            Text(cls.label)
        }
        .font(.system(size: 9.5))
        .foregroundStyle(.secondary)
    }
}

func sectionLabel(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 9, weight: .bold))
        .tracking(0.6)
        .foregroundStyle(.tertiary)
}

struct CheckForUpdatesButton: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        Button("Check for Updates…") { updater.checkForUpdates() }
            .font(.system(size: 10.5))
            .buttonStyle(.plain)
            .foregroundStyle(updater.canCheckForUpdates ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            .disabled(!updater.canCheckForUpdates)
    }
}

struct LaunchAtLoginToggle: View {
    @EnvironmentObject var store: AppStore
    @State private var on = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle("Open at login", isOn: $on)
                .font(.system(size: 11))
                .toggleStyle(.checkbox)
                .onChange(of: on) { _, newValue in
                    do {
                        try store.setLaunchAtLogin(newValue)
                        error = nil
                    } catch {
                        self.error = "Couldn’t change this: \(error.localizedDescription)"
                        on = store.launchAtLogin
                    }
                }
            if let error {
                Text(error).font(.system(size: 9)).foregroundStyle(.red)
            }
        }
        .onAppear { on = store.launchAtLogin }
    }
}
