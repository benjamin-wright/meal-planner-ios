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
    @Environment(FlowRouter.self) private var router
    @Query private var units: [Unit]
    @Query private var settings: [AppSettings]
    
    @State private var resetting = false
    
    var body: some View {
        GlassList {
            Section("Preferred Units") {
                if let setting = settings.first {
                    Button {
                        router.showUnitPicker(selectedID: setting.preferredWeight.id, typeFilter: .weight) { id in
                            guard let unit = units.first(where: { $0.id == id && $0.unitType == .weight }) else { return }
                            setting.preferredWeight = unit
                        }
                    } label: {
                        Text("Weight").badge(setting.preferredWeight.name)
                    }
                    Button {
                        router.showUnitPicker(selectedID: setting.preferredVolume.id, typeFilter: .volume) { id in
                            guard let unit = units.first(where: { $0.id == id && $0.unitType == .volume }) else { return }
                            setting.preferredVolume = unit
                        }
                    } label: {
                        Text("Volume").badge(setting.preferredVolume.name)
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
        .navigationTitle("Settings")
    }
}

#Preview {
    FlowContainer {
        SettingsView()
    }
    .modelContainer(Models.testing.modelContainer)
}
