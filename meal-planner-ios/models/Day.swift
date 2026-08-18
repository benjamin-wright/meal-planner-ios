//
//  Day.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 26/07/2026.
//

import Foundation

enum Day: Int, Codable, CaseIterable {
    case saturday
    case sunday
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday

    var label: String {
        switch self {
        case .saturday:
            return "Saturday"
        case .sunday:
            return "Sunday"
        case .monday:
            return "Monday"
        case .tuesday:
            return "Tuesday"
        case .wednesday:
            return "Wednesday"
        case .thursday:
            return "Thursday"
        case .friday:
            return "Friday"
        }
    }

    var shortLabel: String {
        String(label.prefix(2))
    }
}
