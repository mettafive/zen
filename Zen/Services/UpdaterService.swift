import Foundation
import Sparkle

/// Wraps Sparkle's SPUStandardUpdaterController for use in SwiftUI (no XIB needed).
@MainActor
final class UpdaterService: ObservableObject {
    private let controller: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        // Observe the updater's canCheckForUpdates property
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
