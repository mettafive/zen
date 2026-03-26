import Foundation

enum Constants {
    // Timer
    static let defaultInterval: TimeInterval = 300 // 5 minutes (adaptive start)
    static let minInterval: TimeInterval = 45 // 45 seconds
    static let maxInterval: TimeInterval = 1800 // 30 minutes

    // Adaptive algorithm
    static let intervalStep: TimeInterval = 5 // ±5 seconds per vote
}
