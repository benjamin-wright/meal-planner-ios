//
//  Settings.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import Foundation
import SwiftData

@Model
final class Settings {
    var preferredVolume: ContinuousUnit
    var preferredWeight: ContinuousUnit
    
    init(preferredVolume: ContinuousUnit, preferredWeight: ContinuousUnit) {
        self.preferredVolume = preferredVolume
        self.preferredWeight = preferredWeight
    }
    
    static func sampleData(preferredWeight: ContinuousUnit, preferredVolume: ContinuousUnit) -> Settings {
        return Settings(preferredVolume: preferredVolume, preferredWeight: preferredWeight)
    }
}
