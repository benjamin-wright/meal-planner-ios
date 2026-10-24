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
