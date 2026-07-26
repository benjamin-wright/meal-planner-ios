//
//  CourseType.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 26/07/2026.
//

import Foundation

enum CourseType: Int, Codable, CaseIterable, LabeledEnum {
    var id: Self { self }
    
    case starter
    case main
    case side
    case dessert

    /// Human readable label.
    var label: String {
        switch self {
        case .starter:
            return "Starter"
        case .main:
            return "Main"
        case .side:
            return "Side"
        case .dessert:
            return "Dessert"
        }
    }
}
