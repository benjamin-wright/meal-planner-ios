//
//  SampleData.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 19/09/2025.
//

import Foundation
import SwiftData

@MainActor
class Models {
    static let shared = Models()
    static let testing = Models(testing: true)
    
    let modelContainer: ModelContainer
    
    var context: ModelContext {
        modelContainer.mainContext
    }

    private init(testing: Bool = false) {
        let schema = Schema([
            Category.self,
            CountUnit.self,
            CountUnitCollective.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: testing)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            if testing {
                insertSampleData()
                try context.save()
            }
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    private func insertSampleData() {
        for category in Category.sampleData {
            context.insert(category)
        }
        
        for unit in CountUnit.sampleData {
            context.insert(unit)
        }
    }
}
