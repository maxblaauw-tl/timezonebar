import SwiftUI

@main
struct TimeZoneBarApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            PanelView().environmentObject(store)
        } label: {
            MenuBarLabel().environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: MenuBarIcon.image(scrubbed: !store.isPinnedToNow))
            if store.showMenuBarTime {
                Text(store.timeString(store.now, tz: store.localTimeZone))
            }
        }
    }
}
