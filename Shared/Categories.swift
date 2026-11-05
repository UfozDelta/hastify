import Foundation

enum SpendCategory: String, Codable, CaseIterable, Identifiable {
    case coffee, groceries, dining, transit, shopping, other

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var icon: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .groceries: return "cart.fill"
        case .dining: return "fork.knife"
        case .transit: return "tram.fill"
        case .shopping: return "bag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// Built-in merchant keywords (lowercase, matched as substrings). Your own rules win over these.
    var keywords: [String] {
        switch self {
        case .coffee: return ["starbucks", "coffee", "dunkin", "peet", "cafe", "café"]
        case .groceries: return ["whole foods", "trader joe", "kroger", "safeway", "aldi", "grocery", "costco"]
        case .dining: return ["chipotle", "mcdonald", "restaurant", "pizza", "burger", "sushi", "taco", "subway", "kitchen"]
        case .transit: return ["mta", "omny", "bart", "tfl", "clipper", "transit", "metro", "uber", "lyft"]
        case .shopping: return ["target", "amazon", "walmart", "best buy", "ikea", "nike"]
        case .other: return []
        }
    }
}

/// "If the merchant contains `keyword`, it's `category`."
struct CategoryRule: Codable, Equatable, Hashable {
    var keyword: String
    var category: SpendCategory
}

struct CategoryTotal: Identifiable {
    let category: SpendCategory
    let total: Decimal
    let count: Int
    var id: SpendCategory { category }
}

enum Categorizer {
    /// Your rules first (in order), then the built-in keywords, then `.other`.
    static func category(for merchant: String, rules: [CategoryRule] = []) -> SpendCategory {
        let name = merchant.lowercased()
        for rule in rules {
            let keyword = rule.keyword.trimmingCharacters(in: .whitespaces).lowercased()
            if !keyword.isEmpty, name.contains(keyword) { return rule.category }
        }
        for category in SpendCategory.allCases where category != .other {
            if category.keywords.contains(where: { name.contains($0) }) { return category }
        }
        return .other
    }

    /// Per-category totals, biggest first; categories with no spending are left out.
    static func totals(_ spends: [Spend], rules: [CategoryRule] = []) -> [CategoryTotal] {
        var groups: [SpendCategory: (total: Decimal, count: Int)] = [:]
        for spend in spends {
            let category = category(for: spend.merchant, rules: rules)
            var group = groups[category] ?? (0, 0)
            group.total += spend.amount
            group.count += 1
            groups[category] = group
        }
        return groups
            .map { CategoryTotal(category: $0.key, total: $0.value.total, count: $0.value.count) }
            .sorted { $0.total > $1.total }
    }
}
