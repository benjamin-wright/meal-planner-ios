import Foundation
import os

/// Correlates the app's wait with the actual request lifetime, including a model
/// that finishes late after cancellation. Never logs recipe or ingredient text.
struct RecipieMatchingDiagnostics: Sendable {
    static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "meal-planner-ios",
                               category: "RecipeIngredientMatching")
    private static let signposter = OSSignposter(logger: logger)
    private let requestID = UUID().uuidString
    private let started = ContinuousClock.now

    init(ingredient: Int, position: Int, total: Int, candidateCount: Int) {
        let id = requestID
        Self.logger.notice("Match \(id, privacy: .public) started: ingredient=\(ingredient) position=\(position)/\(total) candidates=\(candidateCount)")
        event("waiting")
    }

    func event(_ outcome: String) {
        let duration = started.duration(to: .now).components
        let milliseconds = Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
        let thermalState = ProcessInfo.processInfo.thermalState.rawValue
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        Self.logger.notice("Match \(requestID, privacy: .public) \(outcome, privacy: .public): elapsed_ms=\(milliseconds) thermal=\(thermalState) low_power=\(lowPower)")
    }

    func measure(_ operation: @Sendable () async throws -> UUID?) async throws -> UUID? {
        let interval = Self.signposter.beginInterval("Ingredient selection", id: Self.signposter.makeSignpostID(),
                                                    "request=\(requestID, privacy: .public)")
        defer { Self.signposter.endInterval("Ingredient selection", interval) }
        return try await withTaskCancellationHandler {
            do {
                try Task.checkCancellation()
                let result = try await operation()
                event("model_returned")
                return result
            } catch is CancellationError {
                event("model_cancelled")
                throw CancellationError()
            } catch {
                event("model_failed")
                // The type is safe to share; descriptions can contain prompt/source data.
                Self.logger.error("Match \(requestID, privacy: .public) error_type=\(String(reflecting: type(of: error)), privacy: .public) error=\(String(describing: error), privacy: .private)")
                throw error
            }
        } onCancel: {
            event("cancellation_requested")
        }
    }
}
