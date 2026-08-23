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
    let entries: [ShoppingListEntry]
}

private struct ShoppingListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ShoppingListEntry.sortOrder) private var entries: [ShoppingListEntry]

    @State private var showingRegenerateConfirmation = false
    @State private var showingAddEntry = false
    @State private var completionTask: Task<Void, Never>?
    @State private var undoSnapshots: [ShoppingListEntrySnapshot] = []
    @State private var listError: String?

    private var sections: [ShoppingListSection] {
        let grouped = Dictionary(grouping: entries) { $0.category?.id }
        return grouped.map { categoryID, entries in
            let category = entries.compactMap(\.category).first
            return ShoppingListSection(
                id: categoryID,
                name: category?.name ?? "Uncategorized",
                order: category?.order ?? Int.max,
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
        completionTask?.cancel()
        do {
            try ShoppingListStore(context: context).regenerate()
            undoSnapshots.removeAll()
        } catch {
            listError = error.localizedDescription
        }
    }

    private func toggle(_ entry: ShoppingListEntry) {
        let checking = !entry.isChecked
        do {
            try ShoppingListStore(context: context).setChecked(checking, id: entry.id)
            if checking {
                restartCompletionTimer()
            } else if !entries.contains(where: { $0.id != entry.id && $0.isChecked }) {
                completionTask?.cancel()
            }
        } catch {
            listError = error.localizedDescription
        }
    }

    private func restartCompletionTimer() {
        completionTask?.cancel()
        completionTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                try removeCheckedEntries()
            } catch is CancellationError {
                return
            } catch {
                listError = error.localizedDescription
            }
        }
    }

    private func removeCheckedEntries() throws {
        let snapshots = try ShoppingListStore(context: context).removeChecked()
        if !snapshots.isEmpty {
            undoSnapshots = snapshots
        }
    }

    private func undoCompletion() {
        guard !undoSnapshots.isEmpty else { return }

        do {
            try ShoppingListStore(context: context).restore(undoSnapshots)
            undoSnapshots.removeAll()
        } catch {
            listError = error.localizedDescription
        }
    }

    var body: some View {
        List {
            if entries.isEmpty {
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
                        }
                    }
                }
            }
        }
        .navigationTitle("Shopping List")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !undoSnapshots.isEmpty {
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
            ShoppingListEntryEdit()
        }
        .onAppear {
            if entries.contains(where: \.isChecked) { restartCompletionTimer() }
        }
        .onDisappear { completionTask?.cancel() }
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

#Preview {
    ListFlowView().modelContainer(Models.testing.modelContainer)
}
