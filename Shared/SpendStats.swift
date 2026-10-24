import Foundation

struct DayTotal: Identifiable {
    let day: Date
    let total: Decimal
    var id: Date { day }
}

struct MerchantTotal: Identifiable {
    let name: String
    let total: Decimal
    let count: Int
    var id: String { name }
}

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
    var money: String { formatted(.currency(code: Currency.code)) }
}

enum SpendStats {
    static func total(_ spends: [Spend]) -> Decimal {
        spends.reduce(0) { $0 + $1.amount }
    }

    static func on(_ day: Date, _ spends: [Spend]) -> [Spend] {
        spends.filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    static func yesterday(_ now: Date = .now) -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: now)!
    }

    /// Spends inside the calendar week/month containing `now`.
    static func during(_ component: Calendar.Component, _ spends: [Spend], now: Date = .now) -> [Spend] {
        guard let interval = Calendar.current.dateInterval(of: component, for: now) else { return [] }
        return spends.filter { interval.contains($0.date) }
    }

    /// Last `days` calendar days ending today, zero-filled, oldest first.
    static func daily(_ spends: [Spend], days: Int, now: Date = .now) -> [DayTotal] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var totals: [Date: Decimal] = [:]
        for spend in spends {
            totals[cal.startOfDay(for: spend.date), default: 0] += spend.amount
        }
        return (0..<days).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            return DayTotal(day: day, total: totals[day] ?? 0)
        }
    }

    static func average(of days: [DayTotal]) -> Decimal {
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.total } / Decimal(days.count)
    }

    /// Average per calendar day since the first logged spend (days with no spend count as zero).
    static func averagePerDay(_ spends: [Spend], now: Date = .now) -> Decimal {
        guard let first = spends.map(\.date).min() else { return 0 }
        let cal = Calendar.current
        let span = cal.dateComponents([.day], from: cal.startOfDay(for: first), to: cal.startOfDay(for: now)).day ?? 0
        return total(spends) / Decimal(max(1, span + 1))
    }

    static func merchants(_ spends: [Spend]) -> [MerchantTotal] {
        var groups: [String: (name: String, total: Decimal, count: Int)] = [:]
        for spend in spends {
            let name = spend.merchant.trimmingCharacters(in: .whitespaces)
            let key = name.lowercased()
            var group = groups[key] ?? (name.isEmpty ? "Unknown" : name, 0, 0)
            group.total += spend.amount
            group.count += 1
            groups[key] = group
        }
        return groups.values
            .map { MerchantTotal(name: $0.name, total: $0.total, count: $0.count) }
            .sorted { $0.total > $1.total }
    }

    static func lastDays(_ days: Int, _ spends: [Spend], now: Date = .now) -> [Spend] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: now))!
        return spends.filter { $0.date >= start }
    }
}

extension Date {
    /// "Today", "Yesterday", or "Mon, Oct 21".
    var dayLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        return formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
