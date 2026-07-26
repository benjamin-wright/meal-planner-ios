//
//  MealType.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 26/07/2026.
//

import Foundation

enum MealType: Int, Codable, CaseIterable, LabeledEnum {
    var id: Self { self }
    
    case breakfast
    case lunch
    case dinner

    var label: String {
        switch self {
        case .breakfast:
            return "Breakfast"
        case .lunch:
            return "Lunch"
        case .dinner:
            return "Dinner"
        }
    }
}
