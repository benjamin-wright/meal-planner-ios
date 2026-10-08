#if DEBUG
import SwiftUI
import FoundationModels

/// Runs the comparison in the application process, without Canvas instrumentation.
struct RecipieExperimentView: View {
    @State private var inputText = ""
    @State private var temperature = 0.0
    @State private var combinedInstructions = FoundationRecipieExtractor.defaultInstructions
    @State private var ingredientInstructions = RecipieExtractionComparison.ingredientInstructions
    @State private var stepInstructions = RecipieExtractionComparison.stepInstructions
    @State private var status = "Ready"
    @State private var report = "Run the comparison to see results here."
    @State private var runTask: Task<Void, Never>?
    @State private var isCancelling = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Model: \(String(describing: SystemLanguageModel.default.availability))")
                        .font(.caption)
                    HStack {
                        Button("Run comparison", action: startRun)
                            .buttonStyle(.borderedProminent)
                            .disabled(runTask != nil || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("runRecipeComparison")
                        if runTask != nil {
                            Button("Cancel") {
                                isCancelling = true
                                status = "Cancelling…"
                                runTask?.cancel()
                            }
                            .disabled(isCancelling)
                        }
                    }
                    Text(status).font(.subheadline)
                    DisclosureGroup("Input and parameters") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Temperature: \(temperature, specifier: "%.2f")")
                            Slider(value: $temperature, in: 0...1, step: 0.05)
                            editor("OCR text", text: $inputText)
                            Button("Reload bundled OCR", action: loadFixture)
                            editor("Combined instructions", text: $combinedInstructions)
                            editor("Ingredient instructions", text: $ingredientInstructions)
                            editor("Step instructions", text: $stepInstructions)
                        }
                        .disabled(runTask != nil)
                    }
                    Divider()
                    Text(report)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("recipeComparisonReport")
                }
                .padding()
            }
            .navigationTitle("Recipe Experiment")
            .onAppear { if inputText.isEmpty { loadFixture() } }
            .onDisappear { runTask?.cancel() }
        }
    }

    private func editor(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.headline)
            TextEditor(text: text)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 180)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.3)))
                .accessibilityLabel(title)
        }
    }

    private func loadFixture() {
        do {
            guard let url = Bundle.main.url(forResource: "RecipieImportOCR", withExtension: "txt") else {
                throw CocoaError(.fileNoSuchFile)
            }
            inputText = try String(contentsOf: url, encoding: .utf8)
            status = "Ready — \(inputText.count) characters loaded"
        } catch {
            status = "Could not load bundled OCR: \(error.localizedDescription)"
        }
    }

    private func startRun() {
        guard runTask == nil else { return }
        isCancelling = false
        status = "Starting…"
        runTask = Task { @MainActor in
            defer { runTask = nil; isCancelling = false }
            do {
                let json = try await RecipieExtractionComparison.run(
                    text: inputText, temperature: temperature,
                    combinedInstructions: combinedInstructions,
                    ingredientInstructions: ingredientInstructions,
                    stepInstructions: stepInstructions,
                    progress: { status = $0 }
                )
                report = try RecipieExtractionComparison.readableReport(from: json)
                status = "Finished"
                print(report)
            } catch is CancellationError {
                status = "Cancelled"
            } catch {
                status = "Failed"
                report = String(reflecting: error)
            }
        }
    }
}
#endif
