import Foundation

struct MoodSchedule: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 17
    var endMinute: Int = 0
    var days: Set<Int> = [] // 1=Mon ... 7=Sun (ISO weekday)

    var startTotalMinutes: Int { startHour * 60 + startMinute }
    var endTotalMinutes: Int { endHour * 60 + endMinute }
    var crossesMidnight: Bool { startTotalMinutes >= endTotalMinutes }

    func containsTime(hour: Int, minute: Int, weekday: Int) -> Bool {
        guard days.contains(weekday) else { return false }
        let now = hour * 60 + minute
        if crossesMidnight {
            return now >= startTotalMinutes || now < endTotalMinutes
        } else {
            return now >= startTotalMinutes && now < endTotalMinutes
        }
    }

    func overlaps(with other: MoodSchedule) -> Set<Int> {
        let sharedDays = days.intersection(other.days)
        guard !sharedDays.isEmpty else { return [] }

        let aStart = startTotalMinutes, aEnd = endTotalMinutes
        let bStart = other.startTotalMinutes, bEnd = other.endTotalMinutes

        let aRanges: [(Int, Int)] = crossesMidnight ? [(aStart, 1440), (0, aEnd)] : [(aStart, aEnd)]
        let bRanges: [(Int, Int)] = other.crossesMidnight ? [(bStart, 1440), (0, bEnd)] : [(bStart, bEnd)]

        for a in aRanges {
            for b in bRanges {
                if a.0 < b.1 && b.0 < a.1 { return sharedDays }
            }
        }
        return []
    }

    var startFormatted: String { String(format: "%02d:%02d", startHour, startMinute) }
    var endFormatted: String { String(format: "%02d:%02d", endHour, endMinute) }

    var summary: String { "\(startFormatted)–\(endFormatted)" }
}

struct Mood: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var icon: String
    var subtitle: String
    var quotes: [String]
    var reminders: [String]
    var isDefault: Bool
    var schedules: [MoodSchedule]

    init(id: UUID, name: String, icon: String, subtitle: String, quotes: [String], reminders: [String], isDefault: Bool, schedules: [MoodSchedule] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.subtitle = subtitle
        self.quotes = quotes
        self.reminders = reminders
        self.isDefault = isDefault
        self.schedules = schedules
    }

    enum CodingKeys: String, CodingKey {
        case id, name, icon, subtitle, quotes, reminders, isDefault, schedules, schedule
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(quotes, forKey: .quotes)
        try container.encode(reminders, forKey: .reminders)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(schedules, forKey: .schedules)
    }

    // Backward compatibility — old JSON had single `schedule` or no schedules
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        quotes = try container.decode([String].self, forKey: .quotes)
        reminders = try container.decode([String].self, forKey: .reminders)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        // Try new array first, then legacy single schedule
        if let arr = try? container.decode([MoodSchedule].self, forKey: .schedules) {
            schedules = arr
        } else if let legacy = try? container.decodeIfPresent(MoodScheduleLegacy.self, forKey: .schedule) {
            if legacy.enabled {
                schedules = [MoodSchedule(id: UUID(), startHour: legacy.startHour, startMinute: legacy.startMinute, endHour: legacy.endHour, endMinute: legacy.endMinute, days: legacy.days)]
            } else {
                schedules = []
            }
        } else {
            schedules = []
        }
    }

    var hasActiveSchedules: Bool { !schedules.isEmpty }
}

// For migrating old single-schedule JSON
private struct MoodScheduleLegacy: Codable {
    var enabled: Bool
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    var days: Set<Int>
}

