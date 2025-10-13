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
    @Query private var units: [Measure]
    @Query private var settings: [AppSettings]
    
    @State private var resetting = false
    
    var body: some View {
        List {
            Section("Preferred Units") {
                @Bindable var setting = settings[0]
                Picker("Weight", selection: $setting.preferredWeight) {
                    ForEach(units.filter { $0.unitType == .weight }) { unit in
                        Text(unit.name).tag(unit)
                    }
                }
                Picker("Volume", selection: $setting.preferredVolume) {
                    ForEach(units.filter { $0.unitType == .volume }) { unit in
                        Text(unit.name).tag(unit)
                    }
                }
            }
            Section("Admin Actions") {
                Button("Reset", role: .destructive) {
                    resetting = true
                }
            }
        }.confirmationDialog(
            "resetting",
            isPresented: $resetting
        ) {
                Button("Yes, delete it all!", role: .destructive, action: {
                    Models.reset(context)
                })
            Button("Cancel", role: .cancel, action: {})
        } message: {
            Text("Are you sure you want to reset all app data?")
        }
    }
}

#Preview {
    SettingsView().modelContainer(Models.testing.modelContainer)
}
