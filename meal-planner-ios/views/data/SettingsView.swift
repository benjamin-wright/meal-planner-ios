//
//  SettingsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [Settings]
    @Query private var units: [ContinuousUnit]
    
    var body: some View {
        List {
            Section("Preferred Units") {
                Picker("Weight", selection: .constant(settings[0].preferredWeight)) {
                    ForEach(units.filter { $0.unitType == .weight }) { unit in
                        Text(unit.name).tag(unit)
                    }
                }
                Picker("Volume", selection: .constant(settings[0].preferredVolume)) {
                    ForEach(units.filter { $0.unitType == .volume }) { unit in
                        Text(unit.name).tag(unit)
                    }
                }
            }
            Section("Admin Actions") {
                Button("Reset") {
                    
                }
            }
        }
    }
}

#Preview {
    SettingsView().modelContainer(Models.testing.modelContainer)
}
