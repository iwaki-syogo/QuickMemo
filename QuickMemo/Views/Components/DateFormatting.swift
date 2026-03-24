import Foundation

struct DateFormatting {
    static func relativeString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "H:mm"
            return formatter.string(from: date)
        }

        if calendar.isDateInYesterday(date) {
            return "昨日"
        }

        let components = calendar.dateComponents([.day], from: date, to: now)
        if let days = components.day, days >= 2 && days <= 6 {
            return "\(days)日前"
        }

        let currentYear = calendar.component(.year, from: now)
        let dateYear = calendar.component(.year, from: date)

        if dateYear == currentYear {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/M/d"
        return formatter.string(from: date)
    }
}
