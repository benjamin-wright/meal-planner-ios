import Foundation
import Testing
@testable import meal_planner_ios

@MainActor
struct MealComponentMovementTests {
    @Test(arguments: CourseType.allCases)
    func movingIntoAnEmptyCourseChangesOnlyTheMovedCourse(destination: CourseType) {
        let portion = MealComponentDraft(
            source: .ingredient(UUID()), course: destination == .side ? .main : .side,
            quantity: 0.5, unitID: UUID()
        )
        let other = MealComponentDraft(
            source: .recipe(UUID()), course: destination == .dessert ? .main : .dessert
        )
        let components = [other, portion]

        let result = MealComponentMovement.moving(components, id: portion.id, to: destination)

        var movedPortion = portion
        movedPortion.course = destination
        #expect(result == (destination == .dessert ? [other, movedPortion] : [movedPortion, other]))
        #expect(result.first { $0.id == portion.id } == movedPortion)
        #expect(portion.course == (destination == .side ? .main : .side))
    }

    @Test(arguments: [false, true])
    func movingIntoAnOccupiedCourseUsesTheRequestedSideOfTheAnchor(after: Bool) {
        let side = MealComponentDraft(source: .readymeal(UUID()), course: .side)
        let incoming = MealComponentDraft(source: .recipe(UUID()), course: .starter)
        let firstMain = MealComponentDraft(source: .recipe(UUID()), course: .main)
        let secondMain = MealComponentDraft(source: .recipe(UUID()), course: .main)
        let components = [side, incoming, firstMain, secondMain]

        let result = MealComponentMovement.moving(
            components, id: incoming.id, to: .main, relativeTo: secondMain.id, after: after
        )

        var moved = incoming
        moved.course = .main
        #expect(result == (after ? [firstMain, secondMain, moved, side] : [firstMain, moved, secondMain, side]))
        #expect(Set(result.map(\.id)) == Set(components.map(\.id)))
        #expect(incoming.course == .starter)
    }

    @Test func aCourseDropAppendsAndPreservesOtherCourseOrder() {
        let firstDessert = MealComponentDraft(source: .recipe(UUID()), course: .dessert)
        let firstSide = MealComponentDraft(source: .recipe(UUID()), course: .side)
        let incoming = MealComponentDraft(source: .readymeal(UUID()), course: .starter)
        let secondSide = MealComponentDraft(source: .recipe(UUID()), course: .side)
        let secondDessert = MealComponentDraft(source: .recipe(UUID()), course: .dessert)
        let main = MealComponentDraft(source: .recipe(UUID()), course: .main)
        let components = [firstDessert, firstSide, incoming, secondSide, secondDessert, main]

        let result = MealComponentMovement.moving(components, id: incoming.id, to: .side)

        var moved = incoming
        moved.course = .side
        #expect(result == [main, firstSide, secondSide, moved, firstDessert, secondDessert])
    }

    @Test(arguments: [false, true])
    func reorderingUpwardOrDownwardKeepsIdentityAndPortionData(moveDownward: Bool) {
        let starter = MealComponentDraft(source: .recipe(UUID()), course: .starter)
        let first = MealComponentDraft(source: .recipe(UUID()), course: .main)
        let second = MealComponentDraft(source: .readymeal(UUID()), course: .main)
        let third = MealComponentDraft(
            source: .ingredient(UUID()), course: .main, quantity: 0.5, unitID: UUID()
        )
        let side = MealComponentDraft(source: .recipe(UUID()), course: .side)
        let components = [starter, first, second, third, side]

        let result = MealComponentMovement.moving(
            components, id: moveDownward ? first.id : third.id, to: .main,
            relativeTo: moveDownward ? third.id : first.id, after: moveDownward
        )

        #expect(result == (moveDownward
                          ? [starter, second, third, first, side]
                          : [starter, third, first, second, side]))
        #expect(result.first { $0.id == third.id } == third)
    }

    @Test func droppingOnTheDraggedRowLeavesTheOriginalArrayUnchanged() {
        let main = MealComponentDraft(source: .recipe(UUID()), course: .main)
        let side = MealComponentDraft(source: .readymeal(UUID()), course: .side)
        let starter = MealComponentDraft(source: .recipe(UUID()), course: .starter)
        let components = [side, main, starter]

        for after in [false, true] {
            let result = MealComponentMovement.moving(
                components, id: main.id, to: .main, relativeTo: main.id, after: after
            )
            #expect(result == components)
        }
    }

    @Test func identicalRecipeSourcesRemainIndependentWhenOneOccurrenceMoves() {
        let recipeID = UUID()
        let starter = MealComponentDraft(source: .recipe(recipeID), course: .starter)
        let main = MealComponentDraft(source: .recipe(recipeID), course: .main)
        let components = [starter, main]

        let result = MealComponentMovement.moving(
            components, id: main.id, to: .starter, relativeTo: starter.id
        )

        var movedMain = main
        movedMain.course = .starter
        #expect(result == [movedMain, starter])
        #expect(result.count == 2)
        #expect(Set(result.map(\.id)).count == 2)
        #expect(result.map(\.source) == [.recipe(recipeID), .recipe(recipeID)])
        #expect(main.course == .main)
    }

    @Test func missingSourcesAndInvalidAnchorsLeaveEveryValueAndPositionUnchanged() {
        let main = MealComponentDraft(source: .recipe(UUID()), course: .main)
        let portion = MealComponentDraft(
            source: .ingredient(UUID()), course: .side, quantity: 0.5, unitID: UUID()
        )
        let components = [portion, main]
        let invalidMoves: [(id: UUID, course: CourseType, target: UUID?)] = [
            (UUID(), .starter, nil),
            (UUID(), .main, main.id),
            (portion.id, .main, UUID()),
            (portion.id, .dessert, main.id),
            (portion.id, .main, portion.id),
        ]

        for move in invalidMoves {
            let result = MealComponentMovement.moving(
                components, id: move.id, to: move.course, relativeTo: move.target
            )
            #expect(result == components)
        }
        #expect(MealComponentMovement.moving([], id: UUID(), to: .main).isEmpty)
    }
}
