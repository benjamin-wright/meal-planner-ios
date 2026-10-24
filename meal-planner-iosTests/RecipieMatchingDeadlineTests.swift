import Foundation
import Testing
@testable import meal_planner_ios

struct RecipieMatchingDeadlineTests {
    private enum TestFailure: Error { case expected }

    @Test func returnsASelectionOrNoMatch() async throws {
        let selection = UUID()
        let selected = try await RecipieMatchingDeadline.run(timeout: .seconds(5)) { selection }
        let unmatched = try await RecipieMatchingDeadline.run(timeout: .seconds(5)) { nil }

        #expect(selected == selection)
        #expect(unmatched == nil)
    }

    @Test func preservesAnOperationError() async {
        do {
            _ = try await RecipieMatchingDeadline.run(timeout: .seconds(5)) {
                throw TestFailure.expected
            }
            Issue.record("The operation error should be propagated.")
        } catch {
            #expect(error is TestFailure)
        }
    }

    @Test func timeoutReturnsBeforeAnUncooperativeOperationFinishes() async {
        let started = DeadlineTestSignal()
        let release = DeadlineTestSignal()
        let completed = DeadlineTestSignal()
        let observedCancellation = DeadlineTestCancellation()
        let lateSelection = UUID()
        // This also cleans up the suspended fake if the deadline implementation
        // regresses to waiting for its cancelled worker.
        let fallback = releaseAfterDelay(release)

        do {
            _ = try await RecipieMatchingDeadline.run(timeout: .milliseconds(50)) {
                await started.signal()
                await release.wait()
                await observedCancellation.record(Task.isCancelled)
                await completed.signal()
                return lateSelection
            }
            Issue.record("The suspended operation should time out.")
        } catch {
            #expect(error is RecipieMatchingDeadline.Failure)
        }

        #expect(await release.isSignalled == false)
        await release.signal()
        if await started.isSignalled {
            await completed.wait()
        }
        fallback.cancel()
        #expect(await observedCancellation.value == true)

        // A late success must neither resume the old continuation twice nor affect
        // a later request.
        let nextSelection = UUID()
        let next = try? await RecipieMatchingDeadline.run(timeout: .seconds(5)) { nextSelection }
        #expect(next == nextSelection)
    }

    @Test func cancellationReturnsBeforeAnUncooperativeOperationFinishes() async {
        let started = DeadlineTestSignal()
        let release = DeadlineTestSignal()
        let completed = DeadlineTestSignal()
        let observedCancellation = DeadlineTestCancellation()
        let fallback = releaseAfterDelay(release)
        let request = Task {
            try await RecipieMatchingDeadline.run(timeout: .seconds(30)) {
                await started.signal()
                await release.wait()
                await observedCancellation.record(Task.isCancelled)
                await completed.signal()
                return UUID()
            }
        }

        await started.wait()
        request.cancel()
        assertCancellation(await request.result)
        #expect(await release.isSignalled == false)

        await release.signal()
        await completed.wait()
        fallback.cancel()
        #expect(await observedCancellation.value == true)
    }

    @Test func cancellationReachesACooperativeOperation() async {
        let started = DeadlineTestSignal()
        let completed = DeadlineTestSignal()
        let observedCancellation = DeadlineTestCancellation()
        let request = Task {
            try await RecipieMatchingDeadline.run(timeout: .seconds(5)) {
                await started.signal()
                do {
                    try await Task.sleep(for: .seconds(2))
                    await observedCancellation.record(false)
                } catch {
                    await observedCancellation.record(error is CancellationError)
                    await completed.signal()
                    throw error
                }
                await completed.signal()
                return nil
            }
        }

        await started.wait()
        request.cancel()
        assertCancellation(await request.result)
        await completed.wait()
        #expect(await observedCancellation.value == true)
    }

    @Test func anAlreadyCancelledCallerDoesNotLaunchTheOperation() async {
        let begin = DeadlineTestSignal()
        let launched = DeadlineTestSignal()
        let request = Task {
            await begin.wait()
            return try await RecipieMatchingDeadline.run(timeout: .seconds(5)) {
                await launched.signal()
                return nil
            }
        }
        request.cancel()
        await begin.signal()

        assertCancellation(await request.result)
        #expect(await launched.isSignalled == false)
    }

    @Test func anExpiredBudgetDoesNotLaunchTheOperation() async {
        let launched = DeadlineTestSignal()
        do {
            _ = try await RecipieMatchingDeadline.run(timeout: .zero) {
                await launched.signal()
                return nil
            }
            Issue.record("An expired budget should time out.")
        } catch {
            #expect(error is RecipieMatchingDeadline.Failure)
        }
        #expect(await launched.isSignalled == false)
    }

    @Test func immediateCompletionCanRaceCancellationWithoutDoubleResume() async {
        let selection = UUID()
        for _ in 0..<100 {
            let request = Task {
                try await RecipieMatchingDeadline.run(timeout: .seconds(5)) { selection }
            }
            await Task.yield()
            request.cancel()
            switch await request.result {
            case .success(let result): #expect(result == selection)
            case .failure(let error): #expect(error is CancellationError)
            }
        }
    }

    private func assertCancellation(_ result: Result<UUID?, Error>) {
        switch result {
        case .success: Issue.record("The cancelled request should throw cancellation.")
        case .failure(let error): #expect(error is CancellationError)
        }
    }

    private func releaseAfterDelay(_ signal: DeadlineTestSignal) -> Task<Void, Never> {
        Task {
            do {
                try await Task.sleep(for: .seconds(2))
                await signal.signal()
            } catch {}
        }
    }
}

/// Deliberately ignores task cancellation to model inference that is slow to stop.
private actor DeadlineTestSignal {
    private(set) var isSignalled = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isSignalled else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func signal() {
        isSignalled = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending { waiter.resume() }
    }
}

private actor DeadlineTestCancellation {
    private(set) var value: Bool?
    func record(_ value: Bool) { self.value = value }
}
