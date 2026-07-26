//
//  Dish.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 26/07/2026.
//

import Foundation

/// A polymorphic placeholder for the things a meal can consist of:
/// either a full `Recipie`, or a ready-made `Item` (one whose kind is `.readymeal`).
/// Uses Swift's native enum with associated values for type-safe polymorphism.
enum Dish: Identifiable, Hashable, Codable {
    case recipe(UUID)
    case readymeal(UUID)

    /// The identifier of the referenced `Recipie` or `Item`.
    var id: UUID {
        switch self {
        case .recipe(let id), .readymeal(let id):
            return id
        }
    }
}
