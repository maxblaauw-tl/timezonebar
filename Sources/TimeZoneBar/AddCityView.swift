import SwiftUI

struct AddCityView: View {
    @EnvironmentObject var store: AppStore
    @Binding var isPresented: Bool

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var results: (standard: [CatalogEntry], cities: [CatalogEntry]) {
        CityCatalog.search(query)
    }

    /// What Enter picks: the top standard match, else the top city.
    private var topHit: CatalogEntry? {
        let r = results
        return r.standard.first ?? r.cities.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField

            let r = results
            if r.standard.isEmpty && r.cities.isEmpty {
                Text("Nothing matches “\(query)”")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 22)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Standard zones are pinned above cities, always.
                        if !r.standard.isEmpty {
                            sectionLabel(query.isEmpty ? "Standard time zones" : "Standard time zones — matches")
                                .padding(.horizontal, 7)
                                .padding(.bottom, 3)
                            ForEach(r.standard) { e in
                                ResultRow(entry: e) { add(e) }.environmentObject(store)
                            }
                            if query.isEmpty && CityCatalog.standardEntries.count > r.standard.count {
                                Text("Type to search all \(CityCatalog.standardEntries.count) standard zones")
                                    .font(.system(size: 9.5))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 7).padding(.top, 2).padding(.bottom, 4)
                            }
                        }

                        if !r.cities.isEmpty {
                            sectionLabel("Cities")
                                .padding(.horizontal, 7)
                                .padding(.top, r.standard.isEmpty ? 0 : 8)
                                .padding(.bottom, 3)
                            ForEach(r.cities) { e in
                                ResultRow(entry: e) { add(e) }.environmentObject(store)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
                .frame(height: 210)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(.horizontal, Metrics.gutter - 3)
        .padding(.vertical, 10)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { searchFocused = true }
        }
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("City, country, or zone like ET, GMT, JST…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($searchFocused)
                .onSubmit { if let t = topHit { add(t) } }
                .onExitCommand { isPresented = false }
            if !query.isEmpty {
                Button {
                    query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassBackground(in: Capsule())
        .padding(.horizontal, 3)
    }

    private func add(_ entry: CatalogEntry) {
        store.add(entry)
        query = ""
        searchFocused = true
    }
}

struct ResultRow: View {
    @EnvironmentObject var store: AppStore
    let entry: CatalogEntry
    let action: () -> Void

    @State private var hovering = false

    private var tz: TimeZone { TimeZone(identifier: entry.timeZoneID) ?? .current }

    private var alreadyAdded: Bool {
        store.cities.contains { $0.timeZoneID == entry.timeZoneID && $0.name == entry.display }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Text(entry.display)
                    .font(entry.isStandard
                          ? .system(size: 12, weight: .bold, design: .rounded)
                          : .system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(minWidth: entry.isStandard ? 40 : 0, alignment: .leading)
                    .lineLimit(1)

                Text(entry.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 6)

                Text(store.timeString(store.now, tz: tz))
                    .font(.system(size: 11.5, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.secondary)

                Image(systemName: alreadyAdded ? "checkmark" : "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(alreadyAdded ? Color.secondary : Color.accentColor)
                    .frame(width: 12)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 5.5)
            .background {
                if hovering {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in hovering = h }
    }
}
