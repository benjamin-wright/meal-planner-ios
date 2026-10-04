import AVFoundation
import PhotosUI
import SwiftUI
import VisionKit

enum RecipieImportSource: String, Identifiable {
    case camera, photos
    var id: Self { self }
}

struct RecipieImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = RecipieImportModel()
    @State private var selection: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var showCamera = false
    @State private var initialSourcePresented = false
    let initialSource: RecipieImportSource
    let onImport: (ExtractedRecipie) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if model.pages.isEmpty {
                    ContentUnavailableView("Add Recipe Photos", systemImage: "doc.viewfinder",
                                           description: Text("Scan or choose up to six photos of one recipe."))
                } else {
                    RecipieImportPages(pages: $model.pages)
                        .disabled(model.isBusy)
                }
                if let progress = model.progress {
                    ProgressView { Text(progress) }
                    Button("Stop Processing") { model.cancel() }
                } else {
                    Button("Extract Recipe") { model.extract() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.pages.isEmpty)
                        .accessibilityIdentifier("extractRecipe")
                }
            }
            .padding(.bottom)
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { model.cancel(); dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    EditButton().disabled(model.pages.isEmpty || model.isBusy)
                    Menu {
                        if VNDocumentCameraViewController.isSupported {
                            Button("Scan Recipe", systemImage: "camera") { openCamera() }
                        }
                        Button("Choose Photos", systemImage: "photo.on.rectangle") { showPhotos = true }
                    } label: {
                        Label("Add Photos", systemImage: "plus")
                    }
                    .disabled(model.isBusy || model.pages.count >= RecipieImportModel.maximumPages)
                }
            }
            .photosPicker(isPresented: $showPhotos, selection: $selection,
                          maxSelectionCount: max(1, RecipieImportModel.maximumPages - model.pages.count),
                          selectionBehavior: .ordered, matching: .images)
            .onChange(of: selection) { _, photos in
                model.load(photos)
                selection = []
            }
            .fullScreenCover(isPresented: $showCamera) {
                RecipieDocumentCamera(maximumPages: RecipieImportModel.maximumPages - model.pages.count) { result in
                    showCamera = false
                    switch result {
                    case .success(let images): model.addScans(images)
                    case .failure(let error): model.error = error.localizedDescription
                    }
                } onCancel: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
            .alert("Recipe Import", isPresented: Binding(
                get: { model.error != nil }, set: { if !$0 { model.error = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(model.error ?? "")
            }
            .onChange(of: model.result != nil) { _, hasResult in
                if hasResult, let result = model.result {
                    onImport(result)
                    dismiss()
                }
            }
            .task {
                guard !initialSourcePresented else { return }
                initialSourcePresented = true
                if initialSource == .photos { showPhotos = true } else { openCamera() }
            }
            .onDisappear { model.cancel() }
            .interactiveDismissDisabled(model.isBusy)
        }
    }

    private func openCamera() {
        Task { @MainActor in
            let authorized: Bool
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: authorized = true
            case .notDetermined: authorized = await AVCaptureDevice.requestAccess(for: .video)
            default: authorized = false
            }
            if authorized, VNDocumentCameraViewController.isSupported {
                showCamera = true
            } else {
                model.error = String(localized: "Camera access is unavailable. Choose existing photos, or enable camera access for this app in Settings.")
            }
        }
    }
}

private struct RecipieImportPages: View {
    @Binding var pages: [RecipieImportPage]

    var body: some View {
        List {
            Section {
                ForEach(pages.enumerated(), id: \.element.id) { index, page in
                    HStack(spacing: 16) {
                        Image(uiImage: page.thumbnail)
                            .resizable().scaledToFit().frame(width: 80, height: 110)
                            .accessibilityHidden(true)
                        Text("Photo \(index + 1)")
                    }
                }
                .onDelete { pages.remove(atOffsets: $0) }
                .onMove { pages.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("Keep the pages in reading order. Use Edit to reorder or remove photos.")
            }
        }
    }
}

private struct RecipieDocumentCamera: UIViewControllerRepresentable {
    let maximumPages: Int
    let onFinish: (Result<[Data], Error>) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) { }
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: RecipieDocumentCamera
        init(parent: RecipieDocumentCamera) { self.parent = parent }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            guard scan.pageCount <= parent.maximumPages else {
                parent.onFinish(.failure(RecipieImportError.tooManyPages))
                return
            }
            do {
                let images = try (0..<scan.pageCount).map { index in
                    try autoreleasepool {
                        guard let data = scan.imageOfPage(at: index).jpegData(compressionQuality: 0.95) else {
                            throw RecipieImportError.unreadableImage
                        }
                        return data
                    }
                }
                parent.onFinish(.success(images))
            } catch { parent.onFinish(.failure(error)) }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { parent.onCancel() }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onFinish(.failure(error))
        }
    }
}
