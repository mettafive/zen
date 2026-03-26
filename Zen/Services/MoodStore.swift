import Foundation

@MainActor
final class MoodStore: ObservableObject {
    static let shared = MoodStore()

    @Published var moods: [Mood] = []
    @Published var activeMoodId: UUID = DefaultMoods.buddhaId
    @Published var scheduleOverrideUntil: Date? = nil
    @Published var scheduleOverrideMoodId: UUID? = nil
    @Published var overrideTimeRemaining: String? = nil
    private var overrideTimer: Timer?

    var isOverrideActive: Bool {
        guard let until = scheduleOverrideUntil else { return false }
        return Date() < until
    }

    func overrideSchedule(moodId: UUID) {
        scheduleOverrideMoodId = moodId
        scheduleOverrideUntil = Date().addingTimeInterval(3600)
        setActive(id: moodId)
        startOverrideTimer()
    }

    func clearOverride() {
        scheduleOverrideMoodId = nil
        scheduleOverrideUntil = nil
        overrideTimeRemaining = nil
        overrideTimer?.invalidate()
        overrideTimer = nil
        checkSchedule()
    }

    private func startOverrideTimer() {
        overrideTimer?.invalidate()
        updateOverrideCountdown()
        overrideTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateOverrideCountdown() }
        }
    }

    private func updateOverrideCountdown() {
        guard let until = scheduleOverrideUntil else {
            overrideTimeRemaining = nil
            overrideTimer?.invalidate()
            overrideTimer = nil
            return
        }
        let remaining = until.timeIntervalSinceNow
        if remaining <= 0 {
            clearOverride()
        } else {
            let m = Int(remaining) / 60
            let s = Int(remaining) % 60
            overrideTimeRemaining = String(format: "%02d:%02d", m, s)
        }
    }

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
        guard AppSettings.shared.scheduleEnabled else { return }

        // Override takes priority — skip schedule until it expires
        if let until = scheduleOverrideUntil {
            if Date() < until { return }
            // Override expired — clear it
            scheduleOverrideMoodId = nil
            scheduleOverrideUntil = nil
        }

        let cal = Calendar.current
        let now = Date()
        let hour = cal.component(.hour, from: now)
        let minute = cal.component(.minute, from: now)
        let calWeekday = cal.component(.weekday, from: now)
        let isoWeekday = calWeekday == 1 ? 7 : calWeekday - 1

        for mood in moods {
            for schedule in mood.schedules {
                if schedule.containsTime(hour: hour, minute: minute, weekday: isoWeekday) {
                    if !AppSettings.shared.isActive {
                        AppSettings.shared.isActive = true
                    }
                    if activeMoodId != mood.id {
                        setActive(id: mood.id)
                    }
                    return
                }
            }
        }

        // No schedule matched — apply inactive behavior
        let hasAnySchedule = moods.contains { !$0.schedules.isEmpty }
        guard hasAnySchedule else { return }

        let behavior = AppSettings.shared.inactiveBehavior
        if behavior == "pause" {
            if AppSettings.shared.isActive {
                AppSettings.shared.isActive = false
            }
        } else if let moodId = UUID(uuidString: behavior),
                  moods.contains(where: { $0.id == moodId }) {
            if !AppSettings.shared.isActive {
                AppSettings.shared.isActive = true
            }
            if activeMoodId != moodId {
                setActive(id: moodId)
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
        let quotes = activeMood.quotes.filter { $0.trimmingCharacters(in: .whitespaces).count > 2 }
        guard !quotes.isEmpty else { return "Be present." }
        return pickRandom(from: quotes, used: &recentQuoteIndices)
    }

    func nextReminder() -> String {
        let reminders = activeMood.reminders.filter { $0.trimmingCharacters(in: .whitespaces).count > 2 }
        guard !reminders.isEmpty else { return "Check in with your body." }
        return pickRandom(from: reminders, used: &recentReminderIndices)
    }

    /// Picks a random item, tracking ALL used indices.
    /// Only resets once every item has been shown — guarantees full rotation.
    private func pickRandom(from items: [String], used: inout [Int]) -> String {
        // Filter out stale indices (in case items were deleted)
        used = used.filter { $0 < items.count }

        var available = Array(0..<items.count).filter { !used.contains($0) }
        if available.isEmpty {
            // Every item has been shown — start a new cycle
            used.removeAll()
            available = Array(0..<items.count)
        }
        let index = available.randomElement()!
        used.append(index)
        return items[index]
    }

    // MARK: - CRUD

    func setActive(id: UUID) {
        activeMoodId = id
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
        var cleaned = mood
        cleaned.quotes = mood.quotes.filter { $0.trimmingCharacters(in: .whitespaces).count > 2 }
        cleaned.reminders = mood.reminders.filter { $0.trimmingCharacters(in: .whitespaces).count > 2 }
        moods[index] = cleaned
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

    // MARK: - Schedule helpers

    /// A flattened block representing one mood's schedule on one specific day
    struct ScheduleBlock: Identifiable {
        let id: String // "\(moodId)-\(scheduleId)-\(day)"
        let moodId: UUID
        let scheduleId: UUID
        let day: Int // 1=Mon...7=Sun
        let startMinutes: Int // absolute 0-1440
        let endMinutes: Int // absolute, may be > startMinutes by up to 1440 (midnight crossing)
        let moodName: String
        let moodIcon: String
        let moodIndex: Int // for color assignment
    }

    func allScheduleBlocks() -> [ScheduleBlock] {
        var blocks: [ScheduleBlock] = []
        for (moodIdx, mood) in moods.enumerated() {
            for schedule in mood.schedules {
                for day in schedule.days {
                    let startMin = schedule.startHour * 60 + schedule.startMinute
                    var endMin = schedule.endHour * 60 + schedule.endMinute
                    if endMin <= startMin { endMin += 1440 } // midnight crossing → preserve actual duration
                    blocks.append(ScheduleBlock(
                        id: "\(mood.id)-\(schedule.id)-\(day)",
                        moodId: mood.id,
                        scheduleId: schedule.id,
                        day: day,
                        startMinutes: startMin,
                        endMinutes: endMin,
                        moodName: mood.name,
                        moodIcon: mood.icon,
                        moodIndex: moodIdx
                    ))
                }
            }
        }
        return blocks
    }

    func addScheduleBlock(moodId: UUID, day: Int, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        guard let index = moods.firstIndex(where: { $0.id == moodId }) else { return }
        // Check if mood already has a schedule that includes this day with similar times
        var schedule = MoodSchedule(id: UUID(), startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute, days: [day])
        moods[index].schedules.append(schedule)
        save()
    }

    func removeScheduleBlock(moodId: UUID, scheduleId: UUID, day: Int) {
        guard let moodIdx = moods.firstIndex(where: { $0.id == moodId }) else { return }
        guard let schedIdx = moods[moodIdx].schedules.firstIndex(where: { $0.id == scheduleId }) else { return }

        moods[moodIdx].schedules[schedIdx].days.remove(day)
        // If no days left, remove the schedule entirely
        if moods[moodIdx].schedules[schedIdx].days.isEmpty {
            moods[moodIdx].schedules.remove(at: schedIdx)
        }
        save()
    }

    func updateScheduleTime(moodId: UUID, scheduleId: UUID, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        guard let moodIdx = moods.firstIndex(where: { $0.id == moodId }) else { return }
        guard let schedIdx = moods[moodIdx].schedules.firstIndex(where: { $0.id == scheduleId }) else { return }
        moods[moodIdx].schedules[schedIdx].startHour = startHour
        moods[moodIdx].schedules[schedIdx].startMinute = startMinute
        moods[moodIdx].schedules[schedIdx].endHour = endHour
        moods[moodIdx].schedules[schedIdx].endMinute = endMinute
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
            moods = stored.moods.map { mood in
                var m = mood
                m.quotes = mood.quotes.filter { $0.trimmingCharacters(in: .whitespaces).count > 2 }
                m.reminders = mood.reminders.filter { $0.trimmingCharacters(in: .whitespaces).count > 2 }
                return m
            }
            activeMoodId = stored.activeMoodId

            // Sync defaults — add missing, replace renamed/removed ones
            syncDefaults()
        } catch {
            print("[Zen] Failed to load moods: \(error). Using defaults.")
            moods = DefaultMoods.all
            activeMoodId = DefaultMoods.buddhaId
            save()
        }
    }

    /// Version of the default mood content. Bump this to force-update
    /// quotes and reminders for all default moods on next launch.
    private static let defaultMoodsVersion = 2 // v1 = initial, v2 = curated quotes/reminders

    private func syncDefaults() {
        var changed = false
        let lastVersion = UserDefaults.standard.integer(forKey: "defaultMoodsVersion")
        let needsContentUpdate = lastVersion < Self.defaultMoodsVersion

        for defaultMood in DefaultMoods.all {
            if let index = moods.firstIndex(where: { $0.id == defaultMood.id }) {
                if needsContentUpdate {
                    // Force-update all content for default moods
                    moods[index].name = defaultMood.name
                    moods[index].icon = defaultMood.icon
                    moods[index].subtitle = defaultMood.subtitle
                    moods[index].quotes = defaultMood.quotes
                    moods[index].reminders = defaultMood.reminders
                    changed = true
                } else if moods[index].name != defaultMood.name ||
                          moods[index].icon != defaultMood.icon ||
                          moods[index].subtitle != defaultMood.subtitle {
                    moods[index].name = defaultMood.name
                    moods[index].icon = defaultMood.icon
                    moods[index].subtitle = defaultMood.subtitle
                    changed = true
                }
            } else {
                // Missing default — add it
                moods.append(defaultMood)
                changed = true
            }
        }

        if needsContentUpdate {
            UserDefaults.standard.set(Self.defaultMoodsVersion, forKey: "defaultMoodsVersion")
        }
        if changed { save() }
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
        save()
    }
}
