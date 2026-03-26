import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("baseInterval") var baseInterval: Double = Constants.defaultInterval
    @AppStorage("hapticEnabled") var hapticEnabled: Bool = true
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @AppStorage("isActive") var isActive: Bool = true
    @AppStorage("showQuotes") var showQuotes: Bool = true
    @AppStorage("currentAdaptiveInterval") var currentAdaptiveInterval: Double = Constants.defaultInterval
    @AppStorage("consecutivePresent") var consecutivePresent: Int = 0
    @AppStorage("onboardingComplete") var onboardingComplete: Bool = false
    @AppStorage("quoteX") var quoteX: Double = -1
    @AppStorage("quoteY") var quoteY: Double = -1
    @AppStorage("timerMode") var timerMode: String = "adaptive" // "adaptive" or "static"
    @AppStorage("staticVarianceEnabled") var staticVarianceEnabled: Bool = false
    @AppStorage("staticVarianceMinutes") var staticVarianceMinutes: Double = 1
    @AppStorage("quoteOrder") var quoteOrder: String = "random" // "random" or "sequential"
    @AppStorage("glowTheme") var glowTheme: String = "orange" // "orange" or "white"
    @AppStorage("remindersEnabled") var remindersEnabled: Bool = true
    @AppStorage("reminderIntervalMinutes") var reminderIntervalMinutes: Double = 3
    @AppStorage("staticInterval") var staticInterval: Double = 300 // 5 minutes default

    private init() {}
}
