//
//  UnitEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI
import SwiftData

struct UnitEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    private let id: UUID?
    private let type: UnitType
    private var isEditing: Bool { id != nil }

    @State private var draft: UnitDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @State private var editMode: EditMode = .inactive
    
    init(id: UUID? = nil, type: UnitType) {
        self.id = id
        self.type = type
        self._draft = State(initialValue: UnitDraft(type: type))
    }

    private var validationErrors: [UnitDraft.ValidationError] {
        draft.validate()
    }
    
    private func loadDraft() {
        guard let id else { return }

        do {
            draft = try UnitStore(context: context).draft(id: id)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func save() {
        do {
            try UnitStore(context: context).save(draft, id: id)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func tableRow(magnitude: Binding<Magnitude>, multiple: Bool) -> some View {
        HStack {
            if draft.type != .count {
                TextInput(text: magnitude.abbreviation, placeholder: "abbreviation", alignment: .center).frame(maxWidth: .infinity)
            }
            TextInput(text: magnitude.singular, placeholder: "singular", alignment: .center).frame(maxWidth: .infinity)
            TextInput(text: magnitude.plural, placeholder: "plural", alignment: .center).frame(maxWidth: .infinity)
            if multiple {
                NumberInput(number: magnitude.multiplier, placeholder: "multiplier", alignment: .center).frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .alignmentGuide(.listRowSeparatorTrailing) { viewDimensions in viewDimensions.width }
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                Form {
            Section {
                TextInput(text: $draft.name, label: "Name", placeholder: "unit name")
                NumberInput(number: $draft.base, label: "Base", placeholder: "base")
                if let validationError = validationErrors.first {
                    Text(validationError.localizedDescription)
                        .foregroundStyle(.red)
                }
            }

            Section {
                List {
                    HStack {
                        if draft.type != .count {
                            Text("Abbr").frame(maxWidth: .infinity)
                        }
                        Text("Singular").frame(maxWidth: .infinity)
                        Text("Plural").frame(maxWidth: .infinity)
                        if draft.magnitudes.count > 1 {
                            Text("Multiplier").frame(maxWidth: .infinity)
                        }
                    }.alignmentGuide(.listRowSeparatorLeading) { viewDimensions in
                        return 0
                    }.alignmentGuide(.listRowSeparatorTrailing) { viewDimensions in
                        return viewDimensions.width
                    }
                    
                    ForEach($draft.magnitudes) { magnitude in
                        Section {
                            tableRow(magnitude: magnitude, multiple: draft.magnitudes.count > 1)
                        }
                    }.onDelete { index in
                        draft.magnitudes.remove(atOffsets: index)
                        
                        if draft.magnitudes.count == 1 {
                            draft.magnitudes[0].multiplier = 1
                        }
                    }

                    AddButton {
                        draft.magnitudes.append(
                            Magnitude(singular: "", plural: "", multiplier: 1)
                        )
                    }
                }
            }
            
            Button {
                save()
            } label: {
                Text(isEditing ? "Save" : "Add")
            }.disabled(editMode.isEditing || !validationErrors.isEmpty)
                }
            }
        }
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Unit")
        .onFirstAppear(perform: loadDraft, loading: $isLoading)
        .alert("Unit", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        UnitEdit(type: .weight)
    }
    .modelContainer(Models.testing.modelContainer)
}
