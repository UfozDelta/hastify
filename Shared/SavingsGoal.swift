import Foundation

struct SavingsGoal: Codable, Equatable {
    var name: String
    var target: Decimal
    var startDate: Date
}

struct GoalProgress {
    let saved: Decimal
    let target: Decimal
    /// Consecutive completed days at or under budget, ending yesterday.
    let streak: Int
    /// Estimated finish from the recent pace; nil when not saving anything yet.
    let eta: Date?

    var fraction: Double { target > 0 ? min(1, saved.doubleValue / target.doubleValue) : 0 }
    var isDone: Bool { saved >= target }
    var remaining: Decimal { max(0, target - saved) }
}

enum SavingsStats {
    /// Saved = budget minus spend for each completed day since the goal started (never negative).
    /// Today is left out so the total can't jump the moment the day begins; it updates at midnight.
    static func progress(goal: SavingsGoal, budget: Decimal, spends: [Spend], now: Date = .now) -> GoalProgress {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let start = min(cal.startOfDay(for: goal.startDate), today)
        let dayCount = cal.dateComponents([.day], from: start, to: today).day ?? 0

        var spentByDay: [Date: Decimal] = [:]
        for spend in spends where spend.date >= start {
            spentByDay[cal.startOfDay(for: spend.date), default: 0] += spend.amount
        }
        // Oldest first, completed days only.
        let savedPerDay: [(spent: Decimal, saved: Decimal)] = (0..<dayCount).map { offset in
            let day = cal.date(byAdding: .day, value: offset, to: start)!
            let spent = spentByDay[day] ?? 0
            return (spent, max(0, budget - spent))
        }

        let saved = savedPerDay.reduce(Decimal(0)) { $0 + $1.saved }
        let streak = savedPerDay.reversed().prefix { $0.spent <= budget }.count

        var eta: Date?
        let recent = savedPerDay.suffix(14)
        if !recent.isEmpty, saved < goal.target {
            let pace = recent.reduce(Decimal(0)) { $0 + $1.saved } / Decimal(recent.count)
            if pace > 0 {
                let days = ((goal.target - saved) / pace).doubleValue.rounded(.up)
                eta = cal.date(byAdding: .day, value: Int(days), to: today)
            }
        }
        return GoalProgress(saved: saved, target: goal.target, streak: streak, eta: eta)
    }
}
