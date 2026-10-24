//
//  ListFlowView.swift
//  meal-planner-ios
//

import SwiftUI
import SwiftData

struct ListFlowView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        FlowContainer {
            ShoppingListView(store: ShoppingListStore(context: context))
        }
    }
}

private struct ShoppingListSection: Identifiable {
    let id: UUID?
    let name: String
    let order: Int
    let entries: [ShoppingListRow]
}

/// Values captured before SwiftUI retains a row for a deferred render or transition.
private struct ShoppingListRow: Identifiable {
    let id: UUID
    let name: String
    let formattedQuantity: String
    let isChecked: Bool
    let sortOrder: Int
    let categoryID: UUID?
    let categoryName: String
    let categoryOrder: Int
}

private struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingListEntry.sortOrder) private var entries: [ShoppingListEntry]

    @State private var showingRegenerateConfirmation = false
    @State private var showingAddEntry = false
    @State private var completion: ShoppingListCompletion

    init(store: ShoppingListStore) {
        _completion = State(initialValue: ShoppingListCompletion(store: store))
    }

    private var rows: [ShoppingListRow] {
        entries.compactMap { entry in
            guard !entry.isDeleted, entry.modelContext === context else { return nil }
            let category = entry.category.flatMap { category in
                !category.isDeleted && category.modelContext === context ? category : nil
            }
            let unit = entry.unit.flatMap { unit in
                !unit.isDeleted && unit.modelContext === context ? unit : nil
            }
            return ShoppingListRow(
                id: entry.id,
                name: entry.name,
                formattedQuantity: unit?.toString(forValue: entry.quantity) ?? String(format: "%g", entry.quantity),
                isChecked: entry.isChecked,
                sortOrder: entry.sortOrder,
                categoryID: category?.id,
                categoryName: category?.name ?? "Uncategorized",
                categoryOrder: category?.order ?? Int.max
            )
        }
    }

    private var sections: [ShoppingListSection] {
        let grouped = Dictionary(grouping: rows, by: \.categoryID)
        return grouped.map { categoryID, entries in
            return ShoppingListSection(
                id: categoryID,
                name: entries.first?.categoryName ?? "Uncategorized",
                order: entries.first?.categoryOrder ?? Int.max,
                entries: entries.sorted {
                    let comparison = $0.name.localizedCaseInsensitiveCompare($1.name)
                    return comparison == .orderedSame ? $0.sortOrder < $1.sortOrder : comparison == .orderedAscending
                }
            )
        }
        .sorted {
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        GlassList {
            if rows.isEmpty {
                ContentUnavailableView {
                    Label("Shopping List Is Empty", systemImage: "cart")
                } description: {
                    Text("Generate the list from your planner or add an item directly.")
                } actions: {
                    Button("Generate List") { showingRegenerateConfirmation = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ForEach(sections) { section in
                    Section(section.name) {
                        ForEach(section.entries) { entry in
                            Button { completion.setChecked(!entry.isChecked, id: entry.id) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: entry.isChecked ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(entry.isChecked ? Color.accentColor : Color.secondary)
                                    ItemQuantityRow(name: entry.name, quantity: entry.formattedQuantity)
                                        .foregroundStyle(entry.isChecked ? .secondary : .primary)
                                        .strikethrough(entry.isChecked)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(entry.name), \(entry.formattedQuantity)")
                            .accessibilityValue(entry.isChecked ? "Checked" : "Not checked")
                            .transition(.opacity)
                        }
                    }
                }
            }
        }
        // Query updates can arrive after the store's withAnimation transaction.
        // Animate the displayed membership so removal and Undo both transition.
        .animation(.easeInOut(duration: 0.3), value: rows.map(\.id))
        .navigationTitle("Shopping List")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let completionInterval = completion.interval {
                    ShoppingListCompletionButton(
                        interval: completionInterval,
                        action: completion.cancelPendingRemoval
                    )
                    .id(completionInterval.lowerBound)
                } else if !completion.undoSnapshots.isEmpty {
                    Button("Undo", systemImage: "arrow.uturn.backward", action: completion.undo)
                }
                Button("Add", systemImage: "plus") { showingAddEntry = true }
                Button("Regenerate", systemImage: "arrow.clockwise") {
                    showingRegenerateConfirmation = true
                }
            }
        }
        .confirmationDialog(
            "Regenerate the shopping list?",
            isPresented: $showingRegenerateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Regenerate List", role: .destructive, action: completion.regenerate)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the whole list, including items added directly.")
        }
        .sheet(isPresented: $showingAddEntry) {
            FlowContainer {
                ShoppingListEntryEdit { showingAddEntry = false }
            }
            .background(.ultraThinMaterial)
            .presentationBackground(.clear)
        }
        .onAppear { completion.activate() }
        .onDisappear { completion.deactivate() }
        .alert("Shopping List", isPresented: Binding(
            get: { completion.error != nil },
            set: { if !$0 { completion.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(completion.error ?? "")
        }
    }
}

private struct ShoppingListCompletionButton: View {
    let interval: ClosedRange<Date>
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.25), lineWidth: 2.5)

                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    Circle()
                        .trim(from: 0, to: remainingProgress(at: context.date))
                        .stroke(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }

                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
            }
            .frame(width: 24, height: 24)
        }
        .accessibilityLabel("Cancel pending removal")
        .accessibilityHint("Keeps checked items in the shopping list.")
    }

    private func remainingProgress(at date: Date) -> Double {
        let duration = interval.upperBound.timeIntervalSince(interval.lowerBound)
        guard duration > 0 else { return 0 }

        let remaining = interval.upperBound.timeIntervalSince(date)
        return min(max(remaining / duration, 0), 1)
    }
}

#Preview {
    ListFlowView().modelContainer(Models.testing.modelContainer)
}
