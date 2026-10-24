import SwiftUI

struct MealComponentsEditor: View {
    @Binding var components: [MealComponentDraft]
    let recipies: [Recipie]
    let items: [Item]
    let units: [Unit]
    let onAdd: () -> Void
    let onEdit: (MealComponentDraft) -> Void
    var allowsRecipeEditing = false

    private var sortedComponents: [MealComponentDraft] {
        CourseType.allCases.flatMap { course in
            components.filter { $0.course == course }
        }
    }

    var body: some View {
        Section {
            ForEach(sortedComponents) { component in
                Menu {
                    Picker("Course", selection: course(for: component)) {
                        ForEach(CourseType.allCases) { course in
                            Text(course.label).tag(course)
                        }
                    }
                    .pickerStyle(.menu)

                    switch component.source {
                    case .ingredient:
                        Button("Edit Portion") { onEdit(component) }
                    case .recipe where allowsRecipeEditing:
                        Button("Substitute Ingredients") { onEdit(component) }
                    default:
                        EmptyView()
                    }

                    Button("Delete Dish", role: .destructive) {
                        components.removeAll { $0.id == component.id }
                    }
                } label: {
                    HStack(spacing: 12) {
                        MealComponentRow(component: component, recipies: recipies, items: items, units: units)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(component.course.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                            .accessibilityHidden(true)
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .accessibilityIdentifier("mealComponent-\(component.id)")
                .accessibilityValue(component.course.label)
            }

            Button("Add dish", systemImage: "plus", action: onAdd)
                .accessibilityIdentifier("addDish")
        } header: {
            GlassSectionHeader(title: "Dishes")
        }
    }

    private func course(for component: MealComponentDraft) -> Binding<CourseType> {
        Binding(
            get: { components.first { $0.id == component.id }?.course ?? component.course },
            set: { course in
                guard let index = components.firstIndex(where: { $0.id == component.id }) else { return }
                components[index].course = course
            }
        )
    }
}
