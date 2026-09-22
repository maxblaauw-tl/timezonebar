import Sparkle

/// Thin wrapper so SwiftUI views can trigger a check and reflect whether one is possible,
/// without holding a reference to Sparkle's controller type directly.
final class Updater: ObservableObject {
    static let shared = Updater()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    @Published private(set) var canCheckForUpdates = false

    private init() {
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
