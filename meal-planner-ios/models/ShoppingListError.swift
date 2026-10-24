import Foundation

enum ShoppingListError: LocalizedError {
    case missingSettings
    case missingCountUnit
    case invalidRecipe(String)
    case invalidRecipeIngredient(String)
    case invalidMealIngredient(String)
    case invalidMealIngredientItem(String)
    case missingMealComponentReference
    case incompleteMiscEntry(String)
    case incompatibleUnits
    case emptyName
    case missingItem
    case missingCategory
    case missingUnit
    case invalidQuantity

    var errorDescription: String? {
        switch self {
        case .missingSettings:
            return "Choose preferred weight and volume units in Settings first."
        case .missingCountUnit:
            return "Add a count unit before generating ready meals."
        case .invalidRecipe(let name):
            return "\(name) must serve at least one person before the list can be generated."
        case .invalidRecipeIngredient(let name):
            return "\(name) contains an ingredient quantity that must be finite and greater than zero."
        case .invalidMealIngredient(let name):
            return "The portion of \(name) must be a valid quantity greater than zero."
        case .invalidMealIngredientItem(let name):
            return "\(name) must be an ingredient before it can be added directly to a meal."
        case .missingMealComponentReference:
            return "A recipe, item, or unit used in a planned meal no longer exists."
        case .incompleteMiscEntry(let name):
            return "\(name) needs a category, unit, and positive quantity."
        case .incompatibleUnits:
            return "A unit could not be converted to the preferred unit."
        case .emptyName:
            return "Enter a name for the shopping-list entry."
        case .missingItem:
            return "The selected item no longer exists."
        case .missingCategory:
            return "The selected category no longer exists."
        case .missingUnit:
            return "The selected unit no longer exists."
        case .invalidQuantity:
            return "Quantity must be greater than zero."
        }
    }
}

