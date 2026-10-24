import Observation
import SwiftUI

@MainActor
@Observable
final class FlowRouter {
    /// Each presentation owns its input, completion and return destination. A
    /// nested picker of the same kind cannot replace its parent's callback.
    struct Session<Value>: Hashable {
        let id = UUID()
        let initialValue: Value?
        let returnPath: [Route]
        fileprivate let onComplete: (Value) -> Void

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    enum CreationScreen: Hashable {
        case category
        case item(kind: ItemKind?)
        case unit(type: UnitType, allowsTypeChange: Bool)
        case recipe
        case meal(MealType)
    }

    enum Route: Hashable {
        case units, categories, items, recipies, meals
        case newPlannedMeal(mealType: MealType, day: Day?)
        case editPlannedMeal(UUID)
        case newPlannedMisc, editPlannedMisc(UUID)

        case categoryPicker(Session<UUID>)
        case newCategory, editCategory(UUID)
        case itemPicker(Session<UUID>, kindFilter: ItemKind?)
        case newItem, editItem(UUID)
        case unitPicker(Session<UUID>, typeFilter: UnitType?)
        case newUnit(UnitType), editUnit(id: UUID, type: UnitType)
        case dishPicker(Session<MealComponentDraft>, initialCourse: CourseType)
        case mealComponent(Session<MealComponentDraft>, isEditing: Bool)
        case plannedRecipe(Session<MealComponentDraft>)
        case newRecipie, editRecipie(UUID)
        case recipieIngredient(Session<RecipieIngredientDraft>, isEditing: Bool)
        case importedRecipieIngredient(Session<ImportedRecipieIngredient>)
        case mealPicker(Session<UUID>, initialMealType: MealType)
        case mealDiscovery(Session<PlannedMealDraft>, mealType: MealType, plannedMealID: UUID?)
        case newMeal(MealType), newMealDraft(MealDraft), editMeal(UUID)
        case creation(CreationScreen, Session<UUID>)

        fileprivate var sessionID: UUID? {
            switch self {
            case .categoryPicker(let session), .itemPicker(let session, _),
                 .unitPicker(let session, _), .mealPicker(let session, _),
                 .creation(_, let session): session.id
            case .dishPicker(let session, _), .mealComponent(let session, _),
                 .plannedRecipe(let session): session.id
            case .mealDiscovery(let session, _, _): session.id
            case .recipieIngredient(let session, _): session.id
            case .importedRecipieIngredient(let session): session.id
            default: nil
            }
        }
    }

    var path: [Route] = []

    /// Completion consumes a presentation once, including any child screens.
    /// Cancelled presentations cannot later invoke their retained callbacks.
    @discardableResult
    func complete<Value>(_ session: Session<Value>, with value: Value) -> Bool {
        guard path.contains(where: { $0.sessionID == session.id }),
              path.starts(with: session.returnPath) else { return false }
        path = session.returnPath
        session.onComplete(value)
        return true
    }

    @discardableResult
    func showCreation(_ screen: CreationScreen, onCreate: @escaping (UUID) -> Void) -> Session<UUID> {
        let session = session(onComplete: onCreate)
        path.append(.creation(screen, session))
        return session
    }

    @discardableResult
    func showCategoryPicker(selectedID: UUID, onSelect: @escaping (UUID) -> Void) -> Session<UUID> {
        let session = session(initialValue: selectedID, onComplete: onSelect)
        path.append(.categoryPicker(session))
        return session
    }

    @discardableResult
    func showItemPicker(selectedID: UUID, kindFilter: ItemKind? = nil, onSelect: @escaping (UUID) -> Void) -> Session<UUID> {
        let session = session(initialValue: selectedID, onComplete: onSelect)
        path.append(.itemPicker(session, kindFilter: kindFilter))
        return session
    }

    @discardableResult
    func showUnitPicker(selectedID: UUID, typeFilter: UnitType? = nil, onSelect: @escaping (UUID) -> Void) -> Session<UUID> {
        let session = session(initialValue: selectedID, onComplete: onSelect)
        path.append(.unitPicker(session, typeFilter: typeFilter))
        return session
    }

    @discardableResult
    func showDishPicker(initialCourse: CourseType = .main, onSelect: @escaping (MealComponentDraft) -> Void) -> Session<MealComponentDraft> {
        let session = session(onComplete: onSelect)
        path.append(.dishPicker(session, initialCourse: initialCourse))
        return session
    }

    @discardableResult
    func showMealComponent(
        _ component: MealComponentDraft,
        isEditing: Bool,
        allowsRecipeEditing: Bool = false,
        onSave: @escaping (MealComponentDraft) -> Void
    ) -> Session<MealComponentDraft> {
        let session = session(initialValue: component, onComplete: onSave)
        if allowsRecipeEditing, case .recipe = component.source {
            path.append(.plannedRecipe(session))
        } else {
            path.append(.mealComponent(session, isEditing: isEditing))
        }
        return session
    }

    @discardableResult
    func showPlannerMealPicker(mealType: MealType, onSelect: @escaping (UUID) -> Void) -> Session<UUID> {
        let session = session(onComplete: onSelect)
        path.append(.mealPicker(session, initialMealType: mealType))
        return session
    }

    @discardableResult
    func showMealDiscovery(
        mealType: MealType, plannedMealID: UUID?, draft: PlannedMealDraft,
        onSelect: @escaping (PlannedMealDraft) -> Void
    ) -> Session<PlannedMealDraft> {
        let session = session(initialValue: draft, onComplete: onSelect)
        path.append(.mealDiscovery(session, mealType: mealType, plannedMealID: plannedMealID))
        return session
    }

    @discardableResult
    func showRecipieIngredient(
        _ ingredient: RecipieIngredientDraft,
        isEditing: Bool,
        onSave: @escaping (RecipieIngredientDraft) -> Void
    ) -> Session<RecipieIngredientDraft> {
        let session = session(initialValue: ingredient, onComplete: onSave)
        path.append(.recipieIngredient(session, isEditing: isEditing))
        return session
    }

    @discardableResult
    func showImportedRecipieIngredient(
        _ ingredient: ImportedRecipieIngredient,
        onSave: @escaping (ImportedRecipieIngredient) -> Void
    ) -> Session<ImportedRecipieIngredient> {
        let session = session(initialValue: ingredient, onComplete: onSave)
        path.append(.importedRecipieIngredient(session))
        return session
    }

    private func session<Value>(initialValue: Value? = nil, onComplete: @escaping (Value) -> Void) -> Session<Value> {
        Session(initialValue: initialValue, returnPath: path, onComplete: onComplete)
    }
}
