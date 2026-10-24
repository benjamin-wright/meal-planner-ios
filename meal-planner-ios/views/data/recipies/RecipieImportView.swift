import AVFoundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

enum RecipieImportSource: String, Identifiable {
    case camera, photos, pdf
    var id: Self { self }
}

struct RecipieImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model = RecipieImportModel()
    @State private var selection: [PhotosPickerItem] = []
    @State private var showPhotos = false
    @State private var showCamera = false
    @State private var showPDF = false
    @State private var initialSourcePresented = false
    let initialSource: RecipieImportSource
    let catalogue: [RecipieIngredientCatalogEntry]
    let onImport: (ExtractedRecipie) -> Void

    private var isPDF: Bool { initialSource == .pdf }
    private var hasPages: Bool { isPDF ? !model.pdfPages.isEmpty : !model.pages.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if isPDF {
                    if model.pdfPages.isEmpty {
                        ContentUnavailableView("Choose a Recipe PDF", systemImage: "doc",
                                               description: Text("Choose one PDF with selectable text. Keep up to six pages of one recipe."))
                    } else {
                        RecipiePDFPages(pages: $model.pdfPages, fileName: model.pdfFileName)
                            .disabled(model.isBusy)
                    }
                } else if model.pages.isEmpty {
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
                    Button("Extract Recipe") {
                        if isPDF { model.extractPDF(catalogue: catalogue) }
                        else { model.extract(catalogue: catalogue) }
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(!hasPages)
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
                    EditButton().disabled(!hasPages || model.isBusy)
                    if isPDF {
                        Button("Choose PDF", systemImage: "doc.badge.plus") { showPDF = true }
                            .disabled(model.isBusy)
                            .accessibilityIdentifier("chooseRecipePDF")
                    } else {
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
            }
            .photosPicker(isPresented: $showPhotos, selection: $selection,
                          maxSelectionCount: max(1, RecipieImportModel.maximumPages - model.pages.count),
                          selectionBehavior: .ordered, matching: .images)
            .onChange(of: selection) { _, photos in
                model.load(photos)
                selection = []
            }
            .fileImporter(isPresented: $showPDF, allowedContentTypes: [.pdf]) { result in
                switch result {
                case .success(let url): model.loadPDF(from: url)
                case .failure(let error): model.error = error.localizedDescription
                }
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
                switch initialSource {
                case .photos: showPhotos = true
                case .camera: openCamera()
                case .pdf: showPDF = true
                }
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

private struct RecipiePDFPages: View {
    @Binding var pages: [RecipiePDFPage]
    let fileName: String?

    var body: some View {
        List {
            Section {
                ForEach(pages, id: \.pageNumber) { page in
                    HStack(spacing: 16) {
                        if let thumbnail = UIImage(data: page.thumbnailData) {
                            Image(uiImage: thumbnail)
                                .resizable().scaledToFit().frame(width: 100, height: 140)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Page \(page.pageNumber)")
                            if page.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Label("No selectable text. Remove this page to continue.", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("recipePDFPage\(page.pageNumber)")
                }
                .onDelete { pages.remove(atOffsets: $0) }
            } header: {
                if let fileName { Text(fileName).textCase(nil) }
            } footer: {
                Text("Keep up to six pages of one recipe, with no more than 6,000 characters of text. Use Edit to remove unwanted pages. Scanned pages without selectable text cannot be imported.")
            }
        }
    }
}

#Preview("PDF Page Selection") {
    @Previewable @State var pages: [RecipiePDFPage] = {
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 400)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            ("Carrot soup\nServes 2\nIngredients\n200 g carrots\n500 ml milk" as NSString)
                .draw(in: bounds.insetBy(dx: 20, dy: 20), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 18), .foregroundColor: UIColor.black
                ])
            context.beginPage()
        }
        return (try? RecipiePDFImport.read(data: data)) ?? []
    }()
    NavigationStack {
        RecipiePDFPages(pages: $pages, fileName: "Carrot soup.pdf")
            .navigationTitle("Import Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { EditButton() }
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
