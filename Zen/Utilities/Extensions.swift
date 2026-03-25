import Foundation

extension TimeInterval {
    var minutesAndSeconds: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var humanReadable: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes == 0 {
            return "\(seconds) seconds"
        } else if minutes == 1 && seconds == 0 {
            return "1 minute"
        } else if seconds == 0 {
            return "\(minutes) minutes"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
}
