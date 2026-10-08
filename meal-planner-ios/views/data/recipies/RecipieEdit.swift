//
//  RecipieEdit.swift
//  meal-planner-ios
//
//  Created by Benjamin Wright on 29/09/2025.
//

import SwiftUI
import SwiftData
import FoundationModels
import VisionKit

struct RecipieEdit: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(FlowRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase

    private let id: UUID?
    private var isEditing: Bool { id != nil }

    @State private var draft: RecipieDraft
    @State private var isLoading = false
    @State private var saveError: String?
    @Query private var existing: [Recipie]
    @Query private var units: [Unit]
    @Query private var items: [Item]
    @State private var editMode: EditMode = .inactive
    @State private var importSource: RecipieImportSource?
    @State private var pendingImport: ExtractedRecipie?
    @State private var showReplaceConfirmation = false
    @State private var importReviewMessage: String?
    @State private var importAvailable = false

    init(id: UUID? = nil, mealType: MealType, courseType: CourseType) {
        self.id = id
        self._draft = State(initialValue: RecipieDraft(mealType, courseType))
    }

    private var validationErrors: [RecipieDraft.ValidationError] {
        draft.validate(existingNames: existing.filter { $0.id != id }.map(\.name))
    }

    private var isInvalid: Bool {
        !validationErrors.isEmpty || draft.importedIngredients?.contains {
            !$0.isResolved(items: items, units: units)
        } == true
    }

    private func loadDraft() {
        guard let id else { return }
        do {
            draft = try RecipieStore(context: context).draft(id: id)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func save() {
        do {
            try RecipieStore(context: context).save(draft, id: id)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
    
    private func addStep() {
        draft.steps.append("")
    }

    private func finishImport() {
        guard pendingImport != nil else { return }
        if !draft.name.isEmpty || !draft.summary.isEmpty || !draft.ingredients.isEmpty ||
            !draft.steps.isEmpty || draft.importedIngredients != nil {
            showReplaceConfirmation = true
        } else {
            applyImport()
        }
    }

    private func applyImport() {
        guard let extracted = pendingImport else { return }
        RecipieImportMapper.apply(extracted, to: &draft, items: items, units: units)
        importReviewMessage = RecipieImportMapper.reviewMessage(for: extracted)
        pendingImport = nil
        editMode = .inactive
    }
    
    var detailsSection: some View {
        Section("Details") {
            TextInput(text: $draft.summary, label: "Summary", placeholder: "A basic description", multiline: true)
            EnumPicker(label: "Meal", selection: $draft.mealType).pickerStyle(.segmented)
            EnumPicker(label: "Course", selection: $draft.course).pickerStyle(.segmented)
            IntegerInput(number: $draft.serves, label: "Serves", placeholder: "number of portions")
            IntegerInput(number: $draft.time, label: "Time", placeholder: "time to cook (minutes)", step: 5)
        }
    }
    
    var ingredientsSection: some View {
        Section("Ingredients") {
            ForEach(draft.ingredients) { ingredient in
                Button {
                    router.showRecipieIngredient(ingredient, isEditing: true) { updated in
                        if let index = self.draft.ingredients.firstIndex(where: { $0.id == updated.id }) {
                            self.draft.ingredients[index] = updated
                        }
                    }
                } label: {
                    let item = items.first(where: { $0.id == ingredient.itemID })
                    let unit = units.first(where: { $0.id == ingredient.unitID })
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(item?.name ?? "Unknown item"): \(unit?.toString(forValue: ingredient.quantity) ?? "\(ingredient.quantity)")")
                        if let sourceText = ingredient.sourceText, !sourceText.isEmpty {
                            Text(sourceText).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in draft.ingredients.remove(atOffsets: offsets) }
            if let item = items.first, let unit = units.first {
                Button {
                    router.showRecipieIngredient(
                        RecipieIngredientDraft(itemID: item.id, unitID: unit.id, quantity: 1),
                        isEditing: false
                    ) { ingredient in
                        self.draft.ingredients.append(ingredient)
                    }
                } label: {
                    Text("Add").foregroundColor(.accent)
                }
            }
        }
    }

    private var stepsSection: some View {
        Section("Steps") {
            ForEach($draft.steps.enumerated(), id: \.offset) { index, step in
                TextField("Step \(index + 1)", text: step, axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("recipeStep\(index)")
            }
            .onDelete { offsets in draft.steps.remove(atOffsets: offsets) }
            AddButton(addStep)
                .accessibilityIdentifier("addRecipeStep")
        }
    }

    private var editorContent: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                VStack {
                    GlassForm {
                        Section {
                            TextInput(text: $draft.name, label: "Name", placeholder: "recipe name")
                            if let validationError = validationErrors.first {
                                Text(validationError.localizedDescription)
                                    .foregroundStyle(.red)
                            }
                        }
                        if let importReviewMessage {
                            Section("Import review") {
                                Text(importReviewMessage).font(.callout)
                            }
                        }
                        detailsSection
                        if let imported = Binding($draft.importedIngredients) {
                            ImportedRecipieIngredientsSection(ingredients: imported, items: items, units: units)
                        } else {
                            ingredientsSection
                        }
                        stepsSection
                    }
                    Button(action: save) {
                        Text(isEditing ? "Save" : "Add")
                    }
                    .disabled(editMode.isEditing || isInvalid)
                }
            }
        }
    }

    var body: some View {
        editorContent
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if importAvailable {
                    Menu {
                        if VNDocumentCameraViewController.isSupported {
                            Button("Scan Recipe", systemImage: "camera") { importSource = .camera }
                        }
                        Button("Choose Photos", systemImage: "photo.on.rectangle") { importSource = .photos }
                    } label: {
                        Label("Import Recipe", systemImage: "camera")
                    }
                    .disabled(isLoading || editMode.isEditing)
                    .accessibilityIdentifier("importRecipe")
                }
                EditButton()
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Recipe")
        .onFirstAppear(perform: loadDraft, loading: $isLoading)
        .onAppear { importAvailable = SystemLanguageModel.default.availability == .available }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { importAvailable = SystemLanguageModel.default.availability == .available }
        }
        .onChange(of: SystemLanguageModel.default.availability) { _, availability in
            importAvailable = availability == .available
        }
        .sheet(item: $importSource, onDismiss: finishImport) { source in
            RecipieImportView(initialSource: source) { extracted in pendingImport = extracted }
        }
        .confirmationDialog("Replace Recipe Fields?", isPresented: $showReplaceConfirmation, titleVisibility: .visible) {
            Button("Use Extracted Recipe", role: .destructive) { applyImport() }
            Button("Keep Current Recipe", role: .cancel) { pendingImport = nil }
        } message: {
            Text("Extracted fields will replace your current values, including ingredients and steps when found. Nothing is saved until you tap Save or Add.")
        }
        .alert("Recipe", isPresented: Binding(
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
    FlowContainer {
        RecipieEdit(mealType: .lunch, courseType: .starter)
    }
    .modelContainer(Models.testing.modelContainer)
}
