//
//  Settings.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    var preferredVolume: Measure
    var preferredWeight: Measure
    
    init(preferredVolume: Measure, preferredWeight: Measure) {
        self.preferredVolume = preferredVolume
        self.preferredWeight = preferredWeight
    }
    
    static func clear(_ context: ModelContext) throws {
        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        settings.forEach { setting in
            context.delete(setting)
        }
    }
}
