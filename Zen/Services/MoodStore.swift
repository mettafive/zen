import Foundation

@MainActor
final class MoodStore: ObservableObject {
    static let shared = MoodStore()

    @Published var moods: [Mood] = []
    @Published var activeMoodId: UUID = DefaultMoods.buddhaId

    // Sequential tracking (per session, not persisted)
    private var quoteIndex = 0
    private var reminderIndex = 0
    private var recentQuoteIndices: [Int] = []
    private var recentReminderIndices: [Int] = []

    private var scheduleTimer: Timer?

    private init() {
        load()
        startScheduleChecker()
    }

    // MARK: - Schedule engine

    private func startScheduleChecker() {
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkSchedule() }
        }
        // Also check immediately
        checkSchedule()
    }

    func checkSchedule() {
        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let calWeekday = cal.component(.weekday, from: now)
        let isoWeekday = calWeekday == 1 ? 7 : calWeekday - 1

        for mood in moods {
            for schedule in mood.schedules {
                if schedule.containsTime(hour: hour, minute: minute, weekday: isoWeekday) {
                    if activeMoodId != mood.id {
                        setActive(id: mood.id)
                    }
                    return
                }
            }
        }
    }

    /// Returns the first mood + schedule that conflicts with the given schedule, or nil
    func scheduleConflict(for schedule: MoodSchedule, excludingMood moodId: UUID) -> (mood: Mood, days: Set<Int>)? {
        for other in moods where other.id != moodId {
            for otherSched in other.schedules {
                let conflictDays = schedule.overlaps(with: otherSched)
                if !conflictDays.isEmpty {
                    return (other, conflictDays)
                }
            }
        }
        return nil
    }

    var activeMood: Mood {
        moods.first { $0.id == activeMoodId } ?? moods.first ?? DefaultMoods.buddha
    }

    // MARK: - Quote & Reminder delivery

    func nextQuote() -> String {
        let quotes = activeMood.quotes
        guard !quotes.isEmpty else { return "Be present." }

        if AppSettings.shared.quoteOrder == "sequential" {
            let quote = quotes[quoteIndex % quotes.count]
            quoteIndex += 1
            return quote
        } else {
            return pickRandom(from: quotes, recent: &recentQuoteIndices, recentLimit: min(4, quotes.count - 1))
        }
    }

    func nextReminder() -> String {
        let reminders = activeMood.reminders
        guard !reminders.isEmpty else { return "Check in with your body." }

        if AppSettings.shared.quoteOrder == "sequential" {
            let reminder = reminders[reminderIndex % reminders.count]
            reminderIndex += 1
            return reminder
        } else {
            return pickRandom(from: reminders, recent: &recentReminderIndices, recentLimit: min(4, reminders.count - 1))
        }
    }

    private func pickRandom(from items: [String], recent: inout [Int], recentLimit: Int) -> String {
        var available = Array(0..<items.count).filter { !recent.contains($0) }
        if available.isEmpty {
            recent.removeAll()
            available = Array(0..<items.count)
        }
        let index = available.randomElement()!
        recent.append(index)
        if recent.count > recentLimit { recent.removeFirst() }
        return items[index]
    }

    // MARK: - CRUD

    func setActive(id: UUID) {
        activeMoodId = id
        quoteIndex = 0
        reminderIndex = 0
        recentQuoteIndices.removeAll()
        recentReminderIndices.removeAll()
        save()
    }

    func addMood(_ mood: Mood) {
        moods.append(mood)
        save()
    }

    func updateMood(_ mood: Mood) {
        guard let index = moods.firstIndex(where: { $0.id == mood.id }) else { return }
        moods[index] = mood
        save()
    }

    func deleteMood(id: UUID) {
        guard let mood = moods.first(where: { $0.id == id }), !mood.isDefault else { return }
        moods.removeAll { $0.id == id }
        if activeMoodId == id {
            activeMoodId = DefaultMoods.buddhaId
        }
        save()
    }

    // MARK: - Export & Import

    func exportMood(_ mood: Mood) -> Data {
        var exportable = mood
        exportable.isDefault = false
        exportable.schedules = []
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(exportable)) ?? Data()
    }

    func importMood(from url: URL) throws -> Mood {
        let data = try Data(contentsOf: url)
        var mood = try JSONDecoder().decode(Mood.self, from: data)
        mood.id = UUID()
        mood.isDefault = false
        mood.schedules = []
        addMood(mood)
        return mood
    }

    // MARK: - Persistence

    private var fileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Zen", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("moods.json")
    }

    private struct StoredData: Codable {
        var moods: [Mood]
        var activeMoodId: UUID
    }

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            moods = DefaultMoods.all
            activeMoodId = DefaultMoods.buddhaId
            save()
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let stored = try JSONDecoder().decode(StoredData.self, from: data)
            moods = stored.moods
            activeMoodId = stored.activeMoodId
        } catch {
            print("[Zen] Failed to load moods: \(error). Using defaults.")
            moods = DefaultMoods.all
            activeMoodId = DefaultMoods.buddhaId
            save()
        }
    }

    func save() {
        do {
            let stored = StoredData(moods: moods, activeMoodId: activeMoodId)
            let data = try JSONEncoder().encode(stored)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Zen] Failed to save moods: \(error)")
        }
    }

    func resetToDefaults() {
        moods = DefaultMoods.all
        activeMoodId = DefaultMoods.buddhaId
        quoteIndex = 0
        reminderIndex = 0
        save()
    }
}
