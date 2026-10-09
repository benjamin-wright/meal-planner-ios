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
import Photos
import VisionKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @Query private var units: [Unit]
    @Query private var settings: [AppSettings]
    
    @State private var resetting = false
    @State private var importDiagnostics = ""
    
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
            Section("Recipe Import Diagnostics") {
                Text(importDiagnostics)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("recipeImportDiagnostics")
                Button("Refresh Diagnostics", action: refreshImportDiagnostics)
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
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = info["CFBundleVersion"] as? String ?? "Unknown"
        let modelAvailability = SystemLanguageModel.default.availability
        let cameraPermission: String
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraPermission = "Allowed"
        case .notDetermined: cameraPermission = "Not requested"
        case .denied: cameraPermission = "Denied"
        case .restricted: cameraPermission = "Restricted"
        @unknown default: cameraPermission = "Unknown"
        }
        let photoPermission: String
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: photoPermission = "Full access"
        case .limited: photoPermission = "Limited access"
        case .notDetermined: photoPermission = "Not requested"
        case .denied: photoPermission = "Denied"
        case .restricted: photoPermission = "Restricted"
        @unknown default: photoPermission = "Unknown"
        }
        #if targetEnvironment(simulator)
        let environment = "Simulator"
        #else
        let environment = "Device"
        #endif
        #if DEBUG
        let configuration = "Debug"
        #else
        let configuration = "Release"
        #endif
        let hasCameraUsageDescription = !(info["NSCameraUsageDescription"] as? String ?? "").isEmpty
        importDiagnostics = """
            App: \(version) (\(build))
            OS: \(ProcessInfo.processInfo.operatingSystemVersionString)
            Device: \(UIDevice.current.model)
            Runtime: \(environment), \(configuration)

            Foundation Models: \(String(describing: modelAvailability))
            Import icon: \(modelAvailability == .available ? "Shown" : "Hidden — model unavailable")
            Document scanner supported: \(VNDocumentCameraViewController.isSupported)
            Camera available: \(UIImagePickerController.isSourceTypeAvailable(.camera))
            Camera permission: \(cameraPermission)
            Camera usage description present: \(hasCameraUsageDescription)
            Photo library permission: \(photoPermission)

            Choosing photos uses the system picker and does not require full photo-library access.
            """
    }
}

#Preview {
    FlowContainer {
        SettingsView()
    }
    .modelContainer(Models.testing.modelContainer)
}
