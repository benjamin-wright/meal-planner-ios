#if DEBUG
import Foundation
import SwiftData

/// Test-only composition: the app's views and stores use their normal behavior.
@MainActor
enum UITestConfiguration {
    private enum Fixture: String {
        case sample
        case staleShoppingList = "stale-shopping-list"
        case recipeViewer = "recipe-viewer"
    }

    static func models(environment: [String: String] = ProcessInfo.processInfo.environment) -> Models? {
        guard let token = environment["MEAL_PLANNER_UI_TEST_STORE"] else { return nil }
        guard let identifier = UUID(uuidString: token),
              let fixture = Fixture(rawValue: environment["MEAL_PLANNER_UI_TEST_FIXTURE"] ?? "sample") else {
            preconditionFailure("UI tests must supply a valid store identifier and fixture.")
        }

        // A fresh identifier isolates each test. Relaunches keep that identifier and
        // reopen its on-disk data, so persistence assertions remain meaningful.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MealPlannerUITests", isDirectory: true)
            .appendingPathComponent(identifier.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            preconditionFailure("Could not create the UI test store: \(error)")
        }
        let configuration = ModelConfiguration(
            "UITest", schema: Models.schema,
            url: directory.appendingPathComponent("MealPlanner.store"), cloudKitDatabase: .none
        )
        return Models(configuration: configuration) { context in
            switch fixture {
            case .sample:
                break
            case .staleShoppingList:
                for entry in try context.fetch(FetchDescriptor<ShoppingListEntry>()) {
                    context.delete(entry)
                }
                context.insert(ShoppingListEntry(name: "Previous shopping entry", quantity: 1))
            case .recipeViewer:
                let recipes = try context.fetch(FetchDescriptor<Recipie>())
                guard let recipe = recipes.first(where: { $0.name == "roast chicken" }) else {
                    preconditionFailure("The recipe viewer fixture requires the sample roast chicken recipe.")
                }
                recipe.steps = (1...15).map { number in
                    "Test instruction \(number). Read this full instruction before continuing. Keep the ingredients within reach, check the previous step is complete, and prepare the utensils needed for the next part."
                }
            }
        }
    }
}
#endif
