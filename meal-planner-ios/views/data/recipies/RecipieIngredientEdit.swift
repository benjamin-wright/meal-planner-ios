//
//  RecipieIngredientEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 08/10/2025.
//

import SwiftUI
import SwiftData

struct RecipieIngredientEdit: View {
    var body: some View {
        
    }
}

#Preview {
    struct Preview: View {
//        @Query var recipies: [Recipie]
        
        var body: some View {
            NavigationStack {
                List {
                    RecipieIngredientEdit()
                }
            }
        }
    }
    
    return Preview().modelContainer(Models.testing.modelContainer)
}
