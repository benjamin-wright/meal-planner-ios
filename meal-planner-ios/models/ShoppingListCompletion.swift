import Foundation
import Observation

/// Owns the lifetime of delayed removal and undo, independently of rendering.
@MainActor
@Observable
final class ShoppingListCompletion {
    struct Clock {
        var now: () -> Date = Date.init
        var sleep: (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(for: .seconds(seconds))
        }
    }

    private(set) var interval: ClosedRange<Date>?
    private(set) var undoSnapshots: [ShoppingListEntrySnapshot] = []
    var error: String?

    private let store: ShoppingListStore
    private let clock: Clock
    private let delay: TimeInterval
    private var task: Task<Void, Never>?
    private var operationID: UUID?

    init(store: ShoppingListStore, clock: Clock = Clock(), delay: TimeInterval = 3) {
        self.store = store
        self.clock = clock
        self.delay = delay
    }

    @discardableResult
    func activate() -> Task<Void, Never>? {
        perform {
            if try store.hasCheckedEntries() { restart() }
        }
        return task
    }

    func deactivate() {
        task?.cancel()
        task = nil
        operationID = nil
        interval = nil
    }

    @discardableResult
    func setChecked(_ checked: Bool, id: UUID) -> Task<Void, Never>? {
        perform {
            try store.setChecked(checked, id: id)
            if checked {
                restart()
            } else if try !store.hasCheckedEntries() {
                deactivate()
            }
        }
        return task
    }

    func cancelPendingRemoval() {
        deactivate()
        perform { try store.uncheckAll() }
    }

    func regenerate() {
        deactivate()
        perform {
            try store.regenerate()
            undoSnapshots.removeAll()
        }
    }

    func undo() {
        guard !undoSnapshots.isEmpty else { return }
        perform {
            try store.restore(undoSnapshots)
            undoSnapshots.removeAll()
        }
    }

    private func restart() {
        deactivate()
        let id = UUID()
        operationID = id
        let start = clock.now()
        interval = start...start.addingTimeInterval(delay)
        let sleep = clock.sleep
        let now = clock.now
        let deadline = start.addingTimeInterval(delay)
        task = Task { [weak self] in
            do {
                try await sleep(max(0, deadline.timeIntervalSince(now())))
                try Task.checkCancellation()
                guard let self, self.operationID == id else { return }
                self.deactivate()
                self.perform {
                    let removed = try self.store.removeChecked()
                    if !removed.isEmpty { self.undoSnapshots = removed }
                }
            } catch is CancellationError {
                // A newer check, cancellation or navigation owns the next action.
            } catch {
                guard let self, self.operationID == id else { return }
                self.deactivate()
                self.error = error.localizedDescription
            }
        }
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
