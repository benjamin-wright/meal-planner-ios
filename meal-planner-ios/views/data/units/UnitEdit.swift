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
    private let initialDraft: UnitDraft?
    private var isEditing: Bool { id != nil }

    @State private var draft: UnitDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @State private var editMode: EditMode = .inactive
    
    init(id: UUID? = nil, type: UnitType, draft: UnitDraft? = nil) {
        self.id = id
        self.type = type
        self.initialDraft = draft
        self._draft = State(initialValue: draft ?? UnitDraft(type: type))
    }
    
    private func loadDraft() {
        guard initialDraft == nil, let id else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            guard let unit = try context.fetch(Unit.descriptor(id: id)).first else {
                saveError = "This unit no longer exists."
                return
            }
            draft = UnitDraft(unit: unit)
        } catch {
            saveError = "Could not load this unit: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            let unit: Unit
            if let id {
                guard let existing = try context.fetch(Unit.descriptor(id: id)).first else {
                    saveError = "This unit no longer exists."
                    return
                }
                unit = existing
            } else {
                unit = Unit(name: draft.name, type: draft.type, base: draft.base, magnitudes: draft.magnitudes)
                context.insert(unit)
            }

            unit.name = draft.name
            unit.type = draft.type.rawValue
            unit.base = draft.base
            unit.magnitudes = draft.magnitudes
            try context.save()
            dismiss()
        } catch {
            saveError = "Could not save this unit: \(error.localizedDescription)"
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
            }.disabled(editMode.isEditing || !draft.isValid())
                }
            }
        }
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Unit")
        .task(id: id) {
            loadDraft()
        }
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
