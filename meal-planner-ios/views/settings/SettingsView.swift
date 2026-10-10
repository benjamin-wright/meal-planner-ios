//
//  SettingsView.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI
import SwiftData
import AVFoundation
import FoundationModels
import VisionKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Query private var settings: [AppSettings]
    
    @State private var resetting = false
    @State private var importDiagnostics = ""
    
    var body: some View {
        GlassList {
            Section("Preferred Units") {
                if let setting = settings.first {
                    Button {
                        router.showUnitPicker(selectedID: setting.preferredWeight.id, typeFilter: .weight) { id in
                            guard let unit = try? context.fetch(Unit.descriptor(id: id)).first,
                                  unit.unitType == .weight else { return }
                            setting.preferredWeight = unit
                        }
                    } label: {
                        Text("Weight").badge(setting.preferredWeight.name)
                    }
                    Button {
                        router.showUnitPicker(selectedID: setting.preferredVolume.id, typeFilter: .volume) { id in
                            guard let unit = try? context.fetch(Unit.descriptor(id: id)).first,
                                  unit.unitType == .volume else { return }
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
            Section("Diagnostics") {
                Text(importDiagnostics)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("recipeImportDiagnostics")
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
        .onAppear(perform: refreshImportDiagnostics)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshImportDiagnostics() }
        }
        .onChange(of: SystemLanguageModel.default.availability) { _, _ in
            refreshImportDiagnostics()
        }
    }

    private func refreshImportDiagnostics() {
        let modelAvailability = SystemLanguageModel.default.availability
        let cameraAvailable = VNDocumentCameraViewController.isSupported
            && UIImagePickerController.isSourceTypeAvailable(.camera)
        let permissions: String
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: permissions = "ok"
        case .notDetermined: permissions = "not requested"
        case .denied: permissions = "camera denied"
        case .restricted: permissions = "camera restricted"
        @unknown default: permissions = "unknown"
        }
        importDiagnostics = """
            AI Models: \(String(describing: modelAvailability))
            Camera: \(cameraAvailable ? "available" : "unavailable")
            Permissions: \(permissions)
            """
    }
}

#Preview {
    FlowContainer {
        SettingsView()
    }
    .modelContainer(Models.testing.modelContainer)
}
