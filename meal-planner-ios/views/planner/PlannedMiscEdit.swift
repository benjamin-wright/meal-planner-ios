import SwiftUI
import SwiftData

struct PlannedMiscEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router

    private let id: UUID?
    @Query private var entries: [PlannedMiscEntry]
    @State private var note = ""
    @State private var selectedItem: Item?
    @State private var isLoading = false
    @State private var saveError: String?

    init(id: UUID? = nil) {
        self.id = id
    }

    private func load() {
        guard let id else { return }
        guard let entry = entries.first(where: { $0.id == id }) else {
            saveError = PlannedMiscStore.Error.notFound.localizedDescription
            return
        }
        note = entry.note ?? ""
        selectedItem = entry.item
    }

    private func chooseItem() {
        router.showItemPicker(selectedID: selectedItem?.id ?? UUID()) { itemID in
            guard let item = try? context.fetch(Item.descriptor(id: itemID)).first else { return }
            selectedItem = item
            note = ""
        }
    }

    private func saveNote() {
        do {
            try PlannedMiscStore(context: context).saveNote(note, id: id)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func saveItem() {
        guard let selectedItem else { return }
        do {
            try PlannedMiscStore(context: context).saveItem(selectedItem.id, id: id)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    var body: some View {
        Form {
            Section("Saved item") {
                Button(action: chooseItem) {
                    HStack {
                        Text("Item")
                        Spacer()
                        Text(selectedItem?.name ?? "Choose item")
                            .foregroundStyle(selectedItem == nil ? .secondary : .primary)
                    }
                }
                if selectedItem != nil {
                    Button("Save Item", action: saveItem)
                }
            }

            Section("One-off note") {
                TextInput(text: $note, label: "Note", placeholder: "e.g. birthday candles")
                Button("Save Note", action: saveNote)
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Misc Entry")
        .onFirstAppear(perform: load, loading: $isLoading)
        .alert("Misc Entry", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}
