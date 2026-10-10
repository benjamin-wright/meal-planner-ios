import SwiftUI

enum MealComponentMovement {
    static func moving(
        _ components: [MealComponentDraft], id: UUID, to course: CourseType,
        relativeTo targetID: UUID? = nil, after: Bool = false
    ) -> [MealComponentDraft] {
        guard let source = components.first(where: { $0.id == id }), targetID != id else { return components }
        if let targetID {
            guard components.contains(where: { $0.id == targetID && $0.course == course }) else { return components }
        }
        var moved = source
        moved.course = course
        let remaining = components.filter { $0.id != id }
        return CourseType.allCases.flatMap { currentCourse in
            var dishes = remaining.filter { $0.course == currentCourse }
            if currentCourse == course {
                let position = targetID.flatMap { target in dishes.firstIndex { $0.id == target } }
                    .map { $0 + (after ? 1 : 0) } ?? dishes.endIndex
                dishes.insert(moved, at: position)
            }
            return dishes
        }
    }
}

struct MealComponentsEditor: View {
    @Binding var components: [MealComponentDraft]
    let isEditing: Bool
    let recipies: [Recipie]
    let items: [Item]
    let units: [Unit]
    let onAdd: (CourseType) -> Void
    let onEditPortion: (MealComponentDraft) -> Void
    var onReorderingChanged: (Bool) -> Void = { _ in }
    var viewport: CGRect = .zero
    var scrollBy: (CGFloat) -> Void = { _ in }

    @State private var draggedID: UUID?
    @State private var dragLocation = CGPoint.zero
    @State private var frames: [Target: CGRect] = [:]
    @State private var destination: Destination?
    @State private var scrollDirection = 0
    @GestureState private var isDragging = false
    @AccessibilityFocusState private var focusedComponentID: UUID?

    private enum Target: Hashable {
        case course(CourseType)
        case component(UUID, CourseType)

    }

    private struct Destination: Equatable {
        let course: CourseType
        var anchor: UUID?
        var after = false
    }

    var body: some View {
        Section {
            VStack(spacing: 0) {
                ForEach(CourseType.allCases) { course in
                    VStack(spacing: 0) {
                        if course != .starter { Divider() }
                        courseHeading(course)
                        let dishes = components.filter { $0.course == course }
                        if dishes.isEmpty && isEditing {
                            Text("Drop dish here")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                .accessibilityIdentifier("courseDrop-\(course.label)")
                        }
                        ForEach(dishes) { component in
                            Divider()
                            componentRow(component)
                                .frame(minHeight: 44)
                                .background(destination?.anchor == component.id ? Color.accentColor.opacity(0.12) : Color.clear)
                                .overlay(alignment: destination?.after == true ? .bottom : .top) {
                                    if destination?.anchor == component.id {
                                        Rectangle().fill(.tint).frame(height: 2)
                                    }
                                }
                                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                                    frames[.component(component.id, course)] = $0
                                }
                                .id("mealComponent-\(component.id)")
                                .contextMenu {
                                    if !isEditing { Button("Remove dish", role: .destructive) { remove(component.id) } }
                                }
                        }
                    }
                    .background(destination?.course == course && destination?.anchor == nil ? Color.accentColor.opacity(0.12) : Color.clear)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                        frames[.course(course)] = $0
                    }
                    .id("mealCourse-\(course.label)")
                }
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .overlay {
                GeometryReader { geometry in
                    if let draggedID, let component = components.first(where: { $0.id == draggedID }) {
                        let origin = geometry.frame(in: .global).origin
                        componentLabel(component)
                            .padding(12)
                            .frame(maxWidth: 240)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 8)
                            .position(x: dragLocation.x - origin.x, y: dragLocation.y - origin.y)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            }
        } header: {
            GlassSectionHeader(title: "Dishes")
        }
        .onChange(of: isEditing) { _, editing in if !editing { endDrag() } }
        .onChange(of: isDragging) { _, dragging in
            if !dragging { endDrag() }
        }
        .onDisappear { endDrag() }
        .onChange(of: frames) { _, _ in if draggedID != nil { updateDestination() } }
        .onChange(of: components) { _, updated in
            frames = frames.filter { target, _ in
                if case .component(let id, let course) = target {
                    return updated.contains { $0.id == id && $0.course == course }
                }
                return true
            }
        }
        .task(id: scrollDirection) {
            while scrollDirection != 0 && draggedID != nil && !Task.isCancelled {
                scrollTowardsEdge()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func remove(_ id: UUID) { components.removeAll { $0.id == id } }

    private func courseHeading(_ course: CourseType) -> some View {
        HStack {
            Text(course.label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if !isEditing {
                Button { onAdd(course) } label: { Image(systemName: "plus").frame(width: 44, height: 44) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Add \(course.label) dish")
            }
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("courseHeader-\(course.label)")
    }

    @ViewBuilder
    private func componentRow(_ component: MealComponentDraft) -> some View {
        if isEditing {
            HStack {
                Button(role: .destructive) { remove(component.id) } label: {
                    Image(systemName: "minus.circle.fill").frame(width: 32, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove dish")
                .accessibilityIdentifier("removeMealComponent-\(component.id)")
                componentLabel(component)
                    .opacity(draggedID == component.id ? 0.35 : 1)
                    .accessibilityIdentifier("mealComponent-\(component.id)")
                    .accessibilityFocused($focusedComponentID, equals: component.id)
                    .accessibilityActions { movementAccessibilityActions(for: component) }
                Spacer()
                Image(systemName: "line.horizontal.3")
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Reorder")
                    .accessibilityHint("Drag to another dish or course")
                    .accessibilityValue(accessibilityPosition(of: component))
                    .accessibilityActions { movementAccessibilityActions(for: component) }
                    .accessibilityIdentifier("reorderMealComponent-\(component.id)")
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .global)
                            .updating($isDragging) { _, dragging, _ in dragging = true }
                            .onChanged { value in
                                if draggedID == nil { onReorderingChanged(true) }
                                draggedID = component.id
                                dragLocation = value.location
                                updateDestination()
                                updateScrollDirection()
                            }
                            .onEnded { value in
                                dragLocation = value.location
                                updateDestination()
                                if let destination {
                                    withAnimation {
                                        components = MealComponentMovement.moving(
                                            components, id: component.id, to: destination.course,
                                            relativeTo: destination.anchor, after: destination.after
                                        )
                                    }
                                }
                                endDrag()
                            }
                    )
            }
        } else if case .ingredient = component.source {
            Button { onEditPortion(component) } label: {
                componentLabel(component).frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.primary)
            .accessibilityIdentifier("mealComponent-\(component.id)")
            .accessibilityValue(component.course.label)
        } else {
            componentLabel(component)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("mealComponent-\(component.id)")
        }
    }

    private func componentLabel(_ component: MealComponentDraft) -> some View {
        MealComponentRow(component: component, recipies: recipies, items: items, units: units, isEditing: isEditing)
    }

    private func accessibilityPosition(of component: MealComponentDraft) -> String {
        let dishes = components.filter { $0.course == component.course }
        guard let index = dishes.firstIndex(where: { $0.id == component.id }) else { return component.course.label }
        return "\(component.course.label), \(index + 1) of \(dishes.count)"
    }

    @ViewBuilder
    private func movementAccessibilityActions(for component: MealComponentDraft) -> some View {
        let dishes = components.filter { $0.course == component.course }
        if let index = dishes.firstIndex(where: { $0.id == component.id }) {
            if index > 0 {
                Button("Move up") {
                    moveAccessibly(component.id, to: component.course, relativeTo: dishes[index - 1].id)
                }
            }
            if index + 1 < dishes.count {
                Button("Move down") {
                    moveAccessibly(component.id, to: component.course, relativeTo: dishes[index + 1].id, after: true)
                }
            }
            ForEach(CourseType.allCases.filter { $0 != component.course }) { course in
                Button("Move to \(course.label)") { moveAccessibly(component.id, to: course) }
            }
        }
    }

    private func moveAccessibly(
        _ id: UUID, to course: CourseType, relativeTo anchor: UUID? = nil, after: Bool = false
    ) {
        withAnimation {
            components = MealComponentMovement.moving(components, id: id, to: course, relativeTo: anchor, after: after)
        }
        Task { @MainActor in
            await Task.yield()
            focusedComponentID = id
        }
    }

    private func updateDestination() {
        destination = nil
        for (target, frame) in frames where frame.contains(dragLocation) {
            if case .component(let id, let course) = target {
                destination = Destination(course: course, anchor: id, after: dragLocation.y > frame.midY)
                return
            }
        }
        for (target, frame) in frames where frame.contains(dragLocation) {
            if case .course(let course) = target {
                destination = Destination(course: course)
                return
            }
        }
    }

    private func updateScrollDirection() {
        guard !viewport.isEmpty else { return }
        scrollDirection = dragLocation.y < viewport.minY + 60 ? -1 : (dragLocation.y > viewport.maxY - 60 ? 1 : 0)
    }

    private func scrollTowardsEdge() {
        if scrollDirection > 0, let last = CourseType.allCases.last,
           let frame = frames[.course(last)] {
            scrollBy(min(24, max(0, frame.maxY - viewport.maxY)))
        } else if scrollDirection < 0, let first = CourseType.allCases.first,
                  let frame = frames[.course(first)] {
            scrollBy(-min(24, max(0, viewport.minY - frame.minY)))
        }
    }

    private func endDrag() {
        draggedID = nil
        destination = nil
        scrollDirection = 0
        onReorderingChanged(false)
    }
}
