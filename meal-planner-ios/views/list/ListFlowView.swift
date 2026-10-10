//
//  ListFlowView.swift
//  meal-planner-ios
//

import SwiftUI
import SwiftData

struct ListFlowView: View {
    var body: some View {
        FlowContainer {
            ShoppingListView()
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
    @State private var completionTask: Task<Void, Never>?
    @State private var completionInterval: ClosedRange<Date>?
    @State private var undoSnapshots: [ShoppingListEntrySnapshot] = []
    @State private var listError: String?

    private static let completionDelay: TimeInterval = 3

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

    private func regenerate() {
        cancelCompletionTimer()
        do {
            try ShoppingListStore(context: context).regenerate()
            undoSnapshots.removeAll()
        } catch {
            listError = error.localizedDescription
        }
    }

    private func toggle(_ entry: ShoppingListRow) {
        let checking = !entry.isChecked
        do {
            try ShoppingListStore(context: context).setChecked(checking, id: entry.id)
            if checking {
                restartCompletionTimer()
            } else if !rows.contains(where: { $0.id != entry.id && $0.isChecked }) {
                cancelCompletionTimer()
            }
        } catch {
            listError = error.localizedDescription
        }
    }

    private func restartCompletionTimer() {
        cancelCompletionTimer()
        let start = Date()
        let interval = start...start.addingTimeInterval(Self.completionDelay)
        completionInterval = interval
        completionTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(max(0, interval.upperBound.timeIntervalSinceNow)))
                guard !Task.isCancelled else { return }
                completionTask = nil
                completionInterval = nil
                try removeCheckedEntries()
            } catch is CancellationError {
                return
            } catch {
                listError = error.localizedDescription
            }
        }
    }

    private func cancelCompletionTimer() {
        completionTask?.cancel()
        completionTask = nil
        completionInterval = nil
    }

    private func cancelPendingCompletion() {
        cancelCompletionTimer()
        do {
            try ShoppingListStore(context: context).uncheckAll()
        } catch {
            listError = error.localizedDescription
        }
    }

    private func removeCheckedEntries() throws {
        let snapshots = try withAnimation(.easeInOut(duration: 0.3)) {
            try ShoppingListStore(context: context).removeChecked()
        }
        if !snapshots.isEmpty {
            undoSnapshots = snapshots
        }
    }

    private func undoCompletion() {
        guard !undoSnapshots.isEmpty else { return }

        do {
            try withAnimation(.easeInOut(duration: 0.3)) {
                try ShoppingListStore(context: context).restore(undoSnapshots)
                undoSnapshots.removeAll()
            }
        } catch {
            listError = error.localizedDescription
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
                            Button { toggle(entry) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: entry.isChecked ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(entry.isChecked ? Color.accentColor : Color.secondary)
                                    Text("\(entry.name): \(entry.formattedQuantity)")
                                        .foregroundStyle(entry.isChecked ? .secondary : .primary)
                                        .strikethrough(entry.isChecked)
                                    Spacer(minLength: 0)
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
        .navigationTitle("Shopping List")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let completionInterval {
                    ShoppingListCompletionButton(
                        interval: completionInterval,
                        action: cancelPendingCompletion
                    )
                    .id(completionInterval.lowerBound)
                } else if !undoSnapshots.isEmpty {
                    Button("Undo", systemImage: "arrow.uturn.backward", action: undoCompletion)
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
            Button("Regenerate List", role: .destructive, action: regenerate)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the whole list, including items added directly.")
        }
        .sheet(isPresented: $showingAddEntry) {
            FlowContainer {
                ShoppingListEntryEdit { showingAddEntry = false }
            }
            .presentationBackground(.thinMaterial)
        }
        .onAppear {
            if rows.contains(where: \.isChecked) { restartCompletionTimer() }
        }
        .onDisappear { cancelCompletionTimer() }
        .alert("Shopping List", isPresented: Binding(
            get: { listError != nil },
            set: { if !$0 { listError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(listError ?? "")
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
