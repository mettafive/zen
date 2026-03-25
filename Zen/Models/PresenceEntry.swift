import Foundation
import SwiftData

@Model
final class PresenceEntry {
    var timestamp: Date
    var wasPresent: Bool
    var intervalSeconds: Int

    init(timestamp: Date = .now, wasPresent: Bool, intervalSeconds: Int) {
        self.timestamp = timestamp
        self.wasPresent = wasPresent
        self.intervalSeconds = intervalSeconds
    }
}
