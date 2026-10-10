//
//  Dish.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 26/07/2026.
//

import Foundation

/// A dish is a meal-owned occurrence of a catalogue recipe or item.
struct Dish: Identifiable, Hashable {
    let component: MealComponent
    var id: UUID { component.id }
    var course: CourseType { component.courseEnum }
    var name: String { component.displayName }
}
