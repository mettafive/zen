import SwiftData
import Foundation

@MainActor
final class PresenceStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func logEntry(wasPresent: Bool, intervalSeconds: Int) {
        let entry = PresenceEntry(
            wasPresent: wasPresent,
            intervalSeconds: intervalSeconds
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }

    func todayEntries() -> [PresenceEntry] {
        let startOfDay = Date().startOfDay
        let predicate = #Predicate<PresenceEntry> { entry in
            entry.timestamp >= startOfDay
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.timestamp)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func entries(from startDate: Date, to endDate: Date) -> [PresenceEntry] {
        let predicate = #Predicate<PresenceEntry> { entry in
            entry.timestamp >= startDate && entry.timestamp <= endDate
        }
        let descriptor = FetchDescriptor(predicate: predicate, sortBy: [SortDescriptor(\.timestamp)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func currentStreak() -> Int {
        let descriptor = FetchDescriptor<PresenceEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let entries = try? modelContext.fetch(descriptor) else { return 0 }

        var streak = 0
        for entry in entries {
            if entry.wasPresent {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    func presenceRate(days: Int) -> Double {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let allEntries = entries(from: startDate, to: Date())
        guard !allEntries.isEmpty else { return 0 }
        let presentCount = allEntries.filter(\.wasPresent).count
        return Double(presentCount) / Double(allEntries.count)
    }
}
