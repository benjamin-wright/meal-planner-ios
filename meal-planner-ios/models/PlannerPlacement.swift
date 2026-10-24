import Foundation

enum PlannerPlacement: Hashable {
    case dinner(Day)
    case breakfast
    case lunch

    init?(mealType: MealType, day: Day?) {
        switch (mealType, day) {
        case (.dinner, .some(let day)): self = .dinner(day)
        case (.breakfast, nil): self = .breakfast
        case (.lunch, nil): self = .lunch
        default: return nil
        }
    }
}

/// Empty days move with the same semantics as occupied dinner slots.
struct DinnerSlots {
    private(set) var meals: [Day: UUID]

    mutating func move(from source: Day, to destination: Day) {
        guard let sourceIndex = Day.allCases.firstIndex(of: source),
              let destinationIndex = Day.allCases.firstIndex(of: destination),
              sourceIndex != destinationIndex else { return }
        var ordered = Day.allCases.map { meals[$0] }
        let moved = ordered.remove(at: sourceIndex)
        ordered.insert(moved, at: destinationIndex)
        meals = Dictionary(uniqueKeysWithValues: zip(Day.allCases, ordered).compactMap { day, id in
            id.map { (day, $0) }
        })
    }
}
