#if DEBUG
import Darwin
import Foundation

/// Work around Xcode 27 / iOS 27's automatic model-feedback JSON assertion.
/// Keep this in developer playgrounds; the environment key is undocumented.
@MainActor
enum RecipiePlaygroundSupport {
    /// Run model playgrounds one at a time: the environment belongs to the entire process.
    /// Restore the flag before displaying results so ordinary canvas logging still works.
    static func withoutAutomaticModelFeedback<Result>(
        _ operation: () async throws -> Result
    ) async rethrows -> Result {
        #if targetEnvironment(simulator)
        let key = "XCODE_RUNNING_FOR_PLAYGROUNDS"
        if let value = ProcessInfo.processInfo.environment[key] {
            unsetenv(key)
            defer { setenv(key, value, 1) }
            return try await operation()
        }
        #endif
        return try await operation()
    }
}
#endif
