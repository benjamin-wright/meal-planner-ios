import SwiftUI
import SwiftData

/// A cooking session presented above the app's tabs. Nothing here edits the plan.
struct PlannedMealRecipeViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Query private var meals: [PlannedMeal]
    @Query private var items: [Item]
    @Query private var units: [Unit]
    @State private var selectedComponentID: UUID?
    @State private var page: Page = .summary
    @State private var gathered: Set<IngredientKey> = []

    private enum Page: String, CaseIterable {
        case summary = "Summary"
        case ingredients = "Ingredients"
        case steps = "Steps"

        var symbol: String {
            switch self {
            case .summary: "rectangle.topthird.inset.filled"
            case .ingredients: "checklist"
            case .steps: "list.number"
            }
        }
    }

    // A recipe may occur more than once, with different substitutions in each dish.
    private struct IngredientKey: Hashable {
        let componentID: UUID
        let ingredientID: UUID
    }

    private struct ContentID: Hashable {
        let componentID: UUID
        let page: Page
    }

    init(mealID: UUID) {
        _meals = Query(filter: #Predicate<PlannedMeal> { $0.id == mealID })
    }

    private var meal: PlannedMeal? { meals.first }

    private var recipeComponents: [MealComponent] {
        meal?.orderedComponents.filter { $0.kindEnum == .recipe && $0.recipe != nil } ?? []
    }

    private var selectedComponent: MealComponent? {
        recipeComponents.first { $0.id == selectedComponentID } ?? recipeComponents.first
    }

    private var title: String {
        guard let meal else { return "Recipes" }
        return meal.dayEnum.map { "\($0.label) \(meal.mealTypeEnum.label.lowercased())" }
            ?? meal.mealTypeEnum.label
    }

    private var background: Color {
        colorScheme == .dark
            ? Color(red: 0.082, green: 0.09, blue: 0.098)
            : Color(uiColor: .systemGroupedBackground)
    }

    private var accentForeground: Color {
        colorScheme == .dark ? .accentColor : Color(red: 0, green: 0.38, blue: 0.46)
    }

    private var compactLayout: Bool {
        dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            if compactLayout {
                HStack {
                    Text("Recipes").font(.headline)
                    Spacer()
                    closeButton
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            } else {
                header
            }
            if let component = selectedComponent, let recipe = component.recipe {
                if !compactLayout { recipeTabs }
                let data = RecipeDisplayData(
                    recipe: recipe, component: MealComponentDraft(component: component),
                    servings: meal?.servings, items: items, units: units
                )
                ScrollView {
                    VStack(spacing: 0) {
                        if compactLayout {
                            mealHeading
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(24)
                            recipeTabs
                        }
                        Group {
                            switch page {
                            case .summary: summary(data, component: component)
                            case .ingredients: ingredients(data, component: component)
                            case .steps: steps(data)
                            }
                        }
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(24)
                        if compactLayout && page != .steps {
                            advanceButton.padding(24)
                        }
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityIdentifier("recipeViewerContent")
                .id(ContentID(componentID: component.id, page: page))
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    bottomBar
                }
            } else {
                ContentUnavailableView(
                    meal == nil ? "Meal Not Found" : "No Recipes",
                    systemImage: "book.closed",
                    description: Text(meal == nil
                        ? "This planned meal is no longer available."
                        : "This meal contains no saved recipes to view.")
                )
            }
        }
        // This modal owns its backing surface; it does not use FlowContainer's
        // transparent UIKit containers or its app-tab transition delegate.
        .background(background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 16) {
            mealHeading.frame(maxWidth: .infinity, alignment: .leading)
            closeButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var mealHeading: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.title3.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            if !recipeComponents.isEmpty {
                Text("\(recipeComponents.count) \(recipeComponents.count == 1 ? "recipe" : "recipes")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.primary.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close recipe viewer")
        .accessibilityIdentifier("closeRecipeViewer")
    }

    private var recipeTabs: some View {
        ScrollViewReader { scroll in
            ScrollView(.horizontal) {
                HStack(spacing: 24) {
                    ForEach(recipeComponents) { component in
                        let isSelected = component.id == selectedComponent?.id
                        Button {
                            selectedComponentID = component.id
                        } label: {
                            Text(component.displayName)
                                .font(.subheadline.weight(.semibold))
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(isSelected ? accentForeground : .secondary)
                                .padding(.vertical, 14)
                                .overlay(alignment: .bottom) {
                                    if isSelected {
                                        Rectangle().fill(accentForeground).frame(height: 3)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityIdentifier("recipeViewerTab-\(component.id)")
                        .id(component.id)
                    }
                }
                .padding(.horizontal, 24)
            }
            .scrollIndicators(.hidden)
            .fixedSize(horizontal: false, vertical: true)
            .overlay(alignment: .bottom) { Divider() }
            .accessibilityIdentifier("recipeViewerTabs")
            .onAppear {
                // Compact layouts recreate the strip when the content page changes.
                if let id = selectedComponent?.id { scroll.scrollTo(id, anchor: .center) }
            }
        }
    }

    private func summary(_ data: RecipeDisplayData, component: MealComponent) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                let index = recipeComponents.firstIndex { $0.id == component.id } ?? 0
                Text("Recipe \(index + 1) of \(recipeComponents.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(data.name)
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("recipeViewerName")
                if !data.summary.isEmpty {
                    Text(data.summary)
                        .foregroundStyle(.secondary)
                }
                if data.hasSubstitutions {
                    substitutionNote
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) { summaryMetrics(data) }
                VStack(spacing: 12) { summaryMetrics(data) }
            }

            Divider()
            Text("\(data.ingredients.count) ingredients · \(data.steps.count) steps")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func summaryMetrics(_ data: RecipeDisplayData) -> some View {
        metric(
            "Servings", value: "\(data.servings)", symbol: "person.2",
            accessibilityValue: "\(data.servings)", identifier: "recipeViewerServings"
        )
        metric(
            "Cooking time", value: data.time >= 0 ? "\(data.time) min" : "Not recorded", symbol: "clock",
            accessibilityValue: data.time >= 0 ? "\(data.time) minutes" : "Not recorded",
            identifier: "recipeViewerTime"
        )
    }

    private func metric(
        _ title: String, value: String, symbol: String, accessibilityValue: String, identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).foregroundStyle(accentForeground)
            Text(value).font(.title2.weight(.semibold))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(identifier)
    }

    private var substitutionNote: some View {
        Label("Includes your ingredient substitutions", systemImage: "arrow.triangle.2.circlepath")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func ingredients(_ data: RecipeDisplayData, component: MealComponent) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("Gather ingredients", detail: "\(data.name) · \(data.servings) servings")
            if data.hasSubstitutions { substitutionNote }
            if data.ingredients.isEmpty {
                Text("No ingredients recorded.").foregroundStyle(.secondary)
            } else {
                let count = data.ingredients.filter {
                    gathered.contains(IngredientKey(componentID: component.id, ingredientID: $0.id))
                }.count
                Text("\(count) of \(data.ingredients.count) gathered")
                    .font(.subheadline)
                    .foregroundStyle(accentForeground)
                VStack(spacing: 0) {
                    Divider()
                    ForEach(data.ingredients) { ingredient in
                        ingredientRow(ingredient, componentID: component.id)
                        Divider()
                    }
                }
            }
        }
    }

    private func ingredientRow(_ ingredient: RecipeDisplayData.Ingredient, componentID: UUID) -> some View {
        let key = IngredientKey(componentID: componentID, ingredientID: ingredient.id)
        let isGathered = gathered.contains(key)
        return Button {
            if isGathered { gathered.remove(key) } else { gathered.insert(key) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isGathered ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isGathered ? accentForeground : .secondary)
                Text(ingredient.name)
                    .strikethrough(isGathered)
                    .foregroundStyle(isGathered ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(ingredient.quantity)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(ingredient.name), \(ingredient.quantity)")
        .accessibilityValue(isGathered ? "Gathered" : "Not gathered")
        .accessibilityHint("Double-tap to \(isGathered ? "uncheck" : "check off") this ingredient.")
        .accessibilityIdentifier("recipeViewerIngredient-\(componentID)-\(ingredient.id)")
    }

    private func steps(_ data: RecipeDisplayData) -> some View {
        VStack(alignment: .leading, spacing: 28) {
            sectionHeading("Let’s cook", detail: "\(data.name) · \(data.steps.count) steps")
            if data.steps.isEmpty {
                Text("No method has been recorded for this recipe.").foregroundStyle(.secondary)
            }
            ForEach(Array(data.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 16) {
                    Text("\(index + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentForeground)
                        .frame(minWidth: 32, minHeight: 32)
                        .background(Color.accentColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)
                    Text(step)
                        .font(.body)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Step \(index + 1). \(step)")
                        .accessibilityIdentifier("recipeViewerStep-\(index + 1)")
                }
            }
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
            Text(detail).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if !compactLayout && page != .steps {
                advanceButton
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
            Divider()
            if compactLayout {
                ScrollViewReader { scroll in
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Page.allCases, id: \.self) { section in
                                sectionButton(section, compact: true).id(section)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityIdentifier("recipeViewerSections")
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
                    .onAppear {
                        scroll.scrollTo(page, anchor: .center)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(Page.allCases, id: \.self) { section in
                        sectionButton(section, compact: false)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
            }
        }
        .background(background)
    }

    private var advanceButton: some View {
        Button {
            page = page == .summary ? .ingredients : .steps
        } label: {
            HStack {
                Text(page == .summary ? "Gather ingredients" : "Start cooking")
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .font(.body.weight(.semibold))
            .padding(16)
            .foregroundStyle(Color(red: 0.035, green: 0.14, blue: 0.17))
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func sectionButton(_ section: Page, compact: Bool) -> some View {
        Button { page = section } label: {
            Group {
                if compact {
                    Text(section.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .fixedSize()
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: section.symbol).font(.title3)
                        Text(section.rawValue).font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.vertical, 8)
            .foregroundStyle(page == section ? accentForeground : .secondary)
            .background(page == section ? Color.accentColor.opacity(0.12) : .clear,
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(page == section ? .isSelected : [])
        .accessibilityIdentifier("recipeViewerSection-\(section.rawValue)")
    }
}

#Preview("Recipe viewer") {
    let models = Models.testing
    let meals = try! models.modelContainer.mainContext.fetch(FetchDescriptor<PlannedMeal>())
    return PlannedMealRecipeViewer(mealID: meals.first { $0.dayEnum == .saturday }!.id)
        .modelContainer(models.modelContainer)
}
