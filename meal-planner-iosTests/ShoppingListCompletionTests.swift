import Foundation
import SwiftData
import Testing
@testable import meal_planner_ios

@MainActor
struct ShoppingListCompletionTests {
    @Test func schedulingDelayDoesNotExtendTheDisplayedDeadline() async throws {
        let fixture = try Fixture()
        let operation = fixture.completion.setChecked(true, id: fixture.entries[0].id)
        fixture.clock.advance(by: 2)
        await fixture.clock.waitForSleeps(1)
        fixture.clock.advance(by: 1)
        await operation?.value
        #expect(try fixture.rows().count == 2)
        #expect(fixture.completion.interval == nil)
    }

    @Test func latestCheckRestartsDeadlineAndUndoRestoresOnlyTheRemovedEntries() async throws {
        let fixture = try Fixture()
        let first = fixture.completion.setChecked(true, id: fixture.entries[0].id)
        await fixture.clock.waitForSleeps(1)
        fixture.clock.advance(by: 2)
        let latest = fixture.completion.setChecked(true, id: fixture.entries[1].id)
        await fixture.clock.waitForSleeps(2)
        fixture.clock.advance(by: 1)
        await first?.value
        #expect(try fixture.rows().count == 3)
        #expect(fixture.completion.interval?.upperBound == fixture.clock.now.addingTimeInterval(2))

        fixture.clock.advance(by: 2)
        await latest?.value
        #expect(try fixture.rows().map(\.id) == [fixture.entries[2].id])
        #expect(fixture.completion.undoSnapshots.count == 2)
        fixture.completion.undo()
        #expect(try fixture.rows().count == 3)
        #expect(try fixture.rows().allSatisfy { !$0.isChecked })
        #expect(fixture.completion.undoSnapshots.isEmpty)
        fixture.completion.undo()
        #expect(try fixture.rows().count == 3)
    }

    @Test(arguments: [false, true])
    func cancellingOrUncheckingTheLastEntryInvalidatesTheDeadline(cancelAll: Bool) async throws {
        let fixture = try Fixture()
        let operation = fixture.completion.setChecked(true, id: fixture.entries[0].id)
        await fixture.clock.waitForSleeps(1)
        if cancelAll {
            fixture.completion.cancelPendingRemoval()
        } else {
            fixture.completion.setChecked(false, id: fixture.entries[0].id)
        }
        fixture.clock.advance(by: 10)
        await operation?.value
        #expect(fixture.completion.interval == nil)
        #expect(fixture.completion.undoSnapshots.isEmpty)
        #expect(try fixture.rows().count == 3)
        #expect(try fixture.rows().allSatisfy { !$0.isChecked })
    }

    @Test func uncheckingOneEntryKeepsTheOtherEntriesDeadline() async throws {
        let fixture = try Fixture()
        let first = fixture.completion.setChecked(true, id: fixture.entries[0].id)
        await fixture.clock.waitForSleeps(1)
        let latest = fixture.completion.setChecked(true, id: fixture.entries[1].id)
        await fixture.clock.waitForSleeps(2)
        fixture.completion.setChecked(false, id: fixture.entries[0].id)
        #expect(fixture.completion.interval != nil)
        fixture.clock.advance(by: 3)
        await first?.value
        await latest?.value
        #expect(Set(try fixture.rows().map(\.id)) == [fixture.entries[0].id, fixture.entries[2].id])
    }

    @Test func leavingSuspendsRemovalAndReturningStartsANewDeadline() async throws {
        let fixture = try Fixture()
        let first = fixture.completion.setChecked(true, id: fixture.entries[0].id)
        await fixture.clock.waitForSleeps(1)
        fixture.completion.deactivate()
        fixture.clock.advance(by: 10)
        await first?.value
        #expect(try fixture.rows().count == 3)
        let resumed = fixture.completion.activate()
        await fixture.clock.waitForSleeps(2)
        fixture.clock.advance(by: 3)
        await resumed?.value
        #expect(try fixture.rows().count == 2)
    }

    @Test func failedRegenerationCancelsTheDeadlineAndKeepsUndoAvailable() async throws {
        let fixture = try Fixture()
        let first = fixture.completion.setChecked(true, id: fixture.entries[0].id)
        await fixture.clock.waitForSleeps(1)
        fixture.clock.advance(by: 3)
        await first?.value
        let next = fixture.completion.setChecked(true, id: fixture.entries[1].id)
        await fixture.clock.waitForSleeps(2)
        // This deliberately minimal store has no settings, so generation must fail.
        fixture.completion.regenerate()
        #expect(fixture.completion.error != nil)
        #expect(fixture.completion.undoSnapshots.count == 1)
        fixture.clock.advance(by: 10)
        await next?.value
        #expect(try fixture.rows().count == 2)
        fixture.completion.undo()
        #expect(try fixture.rows().count == 3)
        #expect(fixture.completion.error == nil)
    }

    @Test func successfulRegenerationClearsUndoAndInvalidatesPendingRemoval() async throws {
        let fixture = try Fixture()
        let first = fixture.completion.setChecked(true, id: fixture.entries[0].id)
        await fixture.clock.waitForSleeps(1)
        fixture.clock.advance(by: 3)
        await first?.value
        let next = fixture.completion.setChecked(true, id: fixture.entries[1].id)
        await fixture.clock.waitForSleeps(2)
        let weight = Unit(name: "grams", type: .weight, magnitudes: [])
        let volume = Unit(name: "litres", type: .volume, magnitudes: [])
        fixture.context.insert(AppSettings(preferredVolume: volume, preferredWeight: weight))
        try fixture.context.save()
        fixture.completion.regenerate()
        #expect(fixture.completion.error == nil)
        #expect(fixture.completion.interval == nil)
        #expect(fixture.completion.undoSnapshots.isEmpty)
        #expect(try fixture.rows().isEmpty)
        fixture.clock.advance(by: 10)
        await next?.value
        #expect(try fixture.rows().isEmpty)
    }

    @MainActor
    private struct Fixture {
        let context: ModelContext
        let clock = ManualClock()
        let entries = (0..<3).map { ShoppingListEntry(name: "Entry \($0)", quantity: 1, sortOrder: $0) }
        let completion: ShoppingListCompletion

        init() throws {
            context = try makeTestContext(autosaveEnabled: false)
            entries.forEach(context.insert)
            try context.save()
            completion = ShoppingListCompletion(store: ShoppingListStore(context: context), clock: clock.value)
        }

        func rows() throws -> [ShoppingListEntry] {
            try context.fetch(FetchDescriptor<ShoppingListEntry>(sortBy: [SortDescriptor(\.sortOrder)]))
        }
    }

    /// Sleep deliberately ignores cancellation: the coordinator must reject stale wake-ups.
    @MainActor
    private final class ManualClock {
        var now = Date(timeIntervalSince1970: 0)
        private var sleeps: [(Date, CheckedContinuation<Void, Error>)] = []
        private var sleepCount = 0
        private var observer: (Int, CheckedContinuation<Void, Never>)?

        var value: ShoppingListCompletion.Clock {
            .init(now: { self.now }, sleep: { interval in
                try await withCheckedThrowingContinuation { continuation in
                    self.sleeps.append((self.now.addingTimeInterval(interval), continuation))
                    self.sleepCount += 1
                    if let (count, continuation) = self.observer, self.sleepCount >= count {
                        self.observer = nil
                        continuation.resume()
                    }
                }
            })
        }

        func waitForSleeps(_ count: Int) async {
            guard sleepCount < count else { return }
            await withCheckedContinuation { observer = (count, $0) }
        }

        func advance(by seconds: TimeInterval) {
            now.addTimeInterval(seconds)
            let ready = sleeps.filter { $0.0 <= now }
            sleeps.removeAll { $0.0 <= now }
            ready.forEach { $0.1.resume() }
        }
    }
}
