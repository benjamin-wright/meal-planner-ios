import Foundation
import Synchronization

enum RecipieMatchingDeadline {
    enum Failure: Error {
        case timedOut
    }

    static func run(
        timeout: Duration,
        operation: @escaping @Sendable () async throws -> UUID?
    ) async throws -> UUID? {
        try Task.checkCancellation()
        guard timeout > .zero else { throw Failure.timedOut }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        let race = CompletionRace()
        let result = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                race.start(continuation: continuation, deadline: deadline, operation: operation)
            }
        } onCancel: {
            race.finish(.failure(CancellationError()))
        }
        try Task.checkCancellation()
        return result
    }

    private final class CompletionRace: Sendable {
        private struct State {
            var result: Result<UUID?, Error>?
            var continuation: CheckedContinuation<UUID?, Error>?
            var workers: [Task<Void, Never>] = []
        }

        private let state = Mutex(State())

        func start(
            continuation: CheckedContinuation<UUID?, Error>,
            deadline: ContinuousClock.Instant,
            operation: @escaping @Sendable () async throws -> UUID?
        ) {
            let existingResult: Result<UUID?, Error>? = state.withLock { state in
                if let result = state.result { return result }
                state.continuation = continuation
                return nil
            }
            if let existingResult {
                continuation.resume(with: existingResult)
                return
            }

            // A task group waits for cancelled children before leaving its scope. Model
            // inference may ignore cancellation, so these workers must be unstructured:
            // the caller can leave immediately and a late model result is discarded.
            let operationTask = Task.detached(priority: Task.currentPriority) {
                guard self.isPending else { return }
                do {
                    try Task.checkCancellation()
                    self.finish(.success(try await operation()))
                } catch {
                    self.finish(.failure(error))
                }
            }
            register(operationTask)

            let timerTask = Task.detached(priority: Task.currentPriority) {
                do {
                    try await ContinuousClock().sleep(until: deadline)
                    self.finish(.failure(Failure.timedOut))
                } catch {
                    // Cancellation means the operation or the caller already finished.
                }
            }
            register(timerTask)
        }

        private var isPending: Bool {
            state.withLock { $0.result == nil }
        }

        private func register(_ worker: Task<Void, Never>) {
            let alreadyFinished = state.withLock { state in
                guard state.result == nil else { return true }
                state.workers.append(worker)
                return false
            }
            // A worker may finish before its handle is registered.
            if alreadyFinished { worker.cancel() }
        }

        func finish(_ result: Result<UUID?, Error>) {
            let completion = state.withLock { state -> (
                CheckedContinuation<UUID?, Error>?, [Task<Void, Never>]
            )? in
                guard state.result == nil else { return nil }
                state.result = result
                let completion = (state.continuation, state.workers)
                state.continuation = nil
                state.workers.removeAll()
                return completion
            }
            guard let (continuation, workers) = completion else { return }
            // Cancellation handlers may call back into this object, so never invoke
            // cancellation or resume a continuation while holding the mutex.
            for worker in workers { worker.cancel() }
            continuation?.resume(with: result)
        }
    }
}
