import Foundation
import FoundationModels

/// Complete import result, assembled only after all focused requests succeed.
struct ExtractedRecipie: Equatable, Encodable {
    var isRecipe: Bool
    var name: String?
    var summary: String?
    var serves: Int?
    var cookingMinutes: Int?
    var ingredients: [ExtractedRecipieIngredient]
    var steps: [String]
}

@Generable
struct ExtractedRecipieMetadata: Equatable {
    @Guide(description: "True only if the source contains a recipe, not just unrelated text.")
    var isRecipe: Bool
    var name: String?
    @Guide(description: "A description from the source, or nil. Do not invent a summary.")
    var summary: String?
    @Guide(description: "Explicit number of servings, or nil if missing or ambiguous.")
    var serves: Int?
    @Guide(description: "Explicit cooking time in minutes, or nil. Do not substitute preparation time.")
    var cookingMinutes: Int?
}

@Generable
struct ExtractedRecipieIngredients {
    @Guide(description: "One entry per ingredient. Join ingredient lines wrapped across several OCR lines (e.g. 2 fine egg / noodle nests is one ingredient). Skip allergen codes, page references and other labels that are not ingredients, such as A1,A3. Remove unnecessary adjectives or preparations on common ingredients, e.g. 'Australian' or 'chopped'")
    var ingredients: [ExtractedRecipieIngredient]
}

@Generable
struct ExtractedRecipieIngredient: Equatable, Encodable {
    @Guide(description: "Complete original ingredient line, preserving spelling, amount and unit.")
    var sourceText: String
    @Guide(description: "Ingredient name without quantity, unit or preparation instructions.")
    var name: String
    @Guide(description: "Numeric amount: 80g is 80; 15ml is 15; 1 1/2 cups is 1.5. For 1 sachet (15g), use 15. Nil if unspecified or ambiguous. Do not scale servings.")
    var quantity: Double?
    @Guide(description: "Required unit belonging to quantity: g for 80g; ml for 15ml; cups for 1 1/2 cups. Use count for 2 onions. Use an empty string only if quantity is unspecified or the unit is ambiguous, e.g. salt or vegetable oil.")
    var unit: String
}

@Generable
struct ExtractedRecipieSteps {
    @Guide(description: "One complete instruction per entry, not one per OCR line. Join wrapped lines belonging to the same action; keep numbered or distinct actions separate and in source order. Preserve wording, temperatures, times and preparation details. Do not add instructions.")
    var steps: [String]
}

struct ImportedRecipieIngredient: Identifiable, Hashable {
    var id = UUID()
    var sourceText: String
    var name: String
    var quantityText: String
    var itemID: UUID?
    var unitID: UUID?
    var magnitudeID: UUID?

    func quantity(units: [Unit]) -> Double? {
        guard let unit = units.first(where: { $0.id == unitID }),
              let amount = RecipieImportMapper.parseQuantity(quantityText) else { return nil }
        let multiplier: Double
        if let magnitudeID {
            guard let magnitude = unit.magnitudes.first(where: { $0.id == magnitudeID }) else { return nil }
            multiplier = magnitude.multiplier
        } else {
            multiplier = 1
        }
        let result = amount * multiplier
        return result.isFinite && result > 0 ? result : nil
    }

    func isResolved(items: [Item], units: [Unit]) -> Bool {
        items.contains { $0.id == itemID && $0.itemKind == .ingredient }
            && quantity(units: units) != nil
    }
}

enum RecipieImportMapper {
    static func key(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    /// Accept explicit positive numbers and fractions, but never guess ranges or "to taste".
    static func parseQuantity(_ value: String) -> Double? {
        let fractions = ["½": "1/2", "⅓": "1/3", "⅔": "2/3", "¼": "1/4", "¾": "3/4",
                         "⅛": "1/8", "⅜": "3/8", "⅝": "5/8", "⅞": "7/8"]
        var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "⁄", with: "/")
        for (symbol, fraction) in fractions {
            text = text.replacingOccurrences(of: symbol, with: " " + fraction)
        }
        let parts = text.split(whereSeparator: \.isWhitespace)
        func number(_ part: Substring) -> Double? {
            if part.contains("/") {
                let pair = part.split(separator: "/", omittingEmptySubsequences: false)
                guard pair.count == 2, let numerator = Double(pair[0]), let denominator = Double(pair[1]),
                      numerator >= 0, denominator > 0 else { return nil }
                return numerator / denominator
            }
            return Double(part)
        }
        let result: Double
        if parts.count == 1, let amount = number(parts[0]) {
            result = amount
        } else if parts.count == 2, let whole = Double(parts[0]), whole >= 0,
                  whole.rounded() == whole, parts[1].contains("/"), let fraction = number(parts[1]),
                  fraction > 0, fraction < 1 {
            result = whole + fraction
        } else {
            return nil
        }
        return result.isFinite && result > 0 ? result : nil
    }

    private static func matchingItem(for name: String, in items: [Item]) -> Item? {
        let nameKey = key(name)
        guard !nameKey.isEmpty, nameKey.count <= 80 else { return nil }
        let nameCharacters = Array(nameKey)
        var best: Item?
        var bestScore = Int.max
        var tied = false
        for item in items where item.itemKind == .ingredient {
            let itemKey = key(item.name)
            guard itemKey.count <= 80 else { continue }
            let score: Int
            if itemKey == nameKey {
                score = 0
            } else if nameCharacters.count >= 5, itemKey.count >= 5,
                      abs(nameCharacters.count - itemKey.count) <= (nameCharacters.count >= 9 ? 2 : 1) {
                let other = Array(itemKey)
                var previous = Array(0...other.count)
                for (index, character) in nameCharacters.enumerated() {
                    var current = [index + 1]
                    for (column, otherCharacter) in other.enumerated() {
                        current.append(min(previous[column + 1] + 1, current[column] + 1,
                                           previous[column] + (character == otherCharacter ? 0 : 1)))
                    }
                    previous = current
                }
                score = previous[other.count]
            } else {
                continue
            }
            let maximumDistance = nameCharacters.count >= 9 ? 2 : (nameCharacters.count >= 5 ? 1 : 0)
            guard score <= maximumDistance else { continue }
            if score < bestScore {
                best = item
                bestScore = score
                tied = false
            } else if score == bestScore {
                tied = true
            }
        }
        return tied ? nil : best
    }

    static func ingredient(_ extracted: ExtractedRecipieIngredient, items: [Item], units: [Unit]) -> ImportedRecipieIngredient {
        let item = matchingItem(for: extracted.name, in: items)
        let quantityText = extracted.quantity.flatMap { amount in
            guard amount.isFinite, amount > 0 else { return nil as String? }
            return amount.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
                .grouping(.never).precision(.significantDigits(1...17)))
        } ?? ""
        let sourceUnit = extracted.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ImportedRecipieIngredient(
            sourceText: extracted.sourceText, name: extracted.name,
            quantityText: quantityText, itemID: item?.id
        )
        // Empty or ambiguous units require review; explicit counts use "count".
        guard !sourceUnit.isEmpty else { return result }
        let candidates = unitCandidates(for: sourceUnit, in: units)
        if candidates.count == 1 {
            result.unitID = candidates[0].0.id
            result.magnitudeID = candidates[0].1?.id
        }
        return result
    }

    private static func unitCandidates(for sourceUnit: String, in units: [Unit]) -> [(Unit, Magnitude?)] {
        let unitKey = key(sourceUnit)
        if ["count", "each"].contains(unitKey) {
            let plain = units.filter { $0.unitType == .count && $0.magnitudes.isEmpty }
            let named = plain.filter { ["count", "each"].contains(key($0.name)) }
            return (named.isEmpty ? plain : named).map { ($0, nil) }
        }
        var candidates: [(Unit, Magnitude?)] = []
        for unit in units {
            let magnitudes = unit.magnitudes.filter {
                [$0.abbreviation, $0.singular, $0.plural].filter { !$0.isEmpty }.contains { key($0) == unitKey }
            }
            if !magnitudes.isEmpty {
                candidates.append(contentsOf: magnitudes.map { (unit, $0) })
            } else if key(unit.name) == unitKey {
                candidates.append((unit, nil))
            }
        }
        return candidates
    }

    /// Rejects non-ingredient noise such as reference codes ("A1,A3"): no quantity and no word of 3+ letters.
    static func isPlausibleIngredient(_ ingredient: ExtractedRecipieIngredient) -> Bool {
        if let amount = ingredient.quantity, amount.isFinite, amount > 0 { return true }
        var run = 0
        for character in ingredient.name {
            run = character.isLetter ? run + 1 : 0
            if run >= 3 { return true }
        }
        return false
    }

    static func apply(_ extracted: ExtractedRecipie, to draft: inout RecipieDraft, items: [Item], units: [Unit]) {
        if let name = extracted.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            draft.name = name
        }
        if let summary = extracted.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            draft.summary = summary
        }
        if let serves = extracted.serves, serves > 0 { draft.serves = serves }
        if let time = extracted.cookingMinutes, time >= 0 { draft.time = time }
        if !extracted.ingredients.isEmpty {
            draft.importedIngredients = extracted.ingredients.filter(isPlausibleIngredient).map { ingredient($0, items: items, units: units) }
            draft.ingredients = []
        }
        let steps = extracted.steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !steps.isEmpty { draft.steps = steps }
    }

    static func reviewMessage(for extracted: ExtractedRecipie) -> String {
        var missing: [String] = []
        if extracted.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { missing.append(String(localized: "name")) }
        if extracted.serves == nil || extracted.serves! <= 0 { missing.append(String(localized: "servings")) }
        if extracted.cookingMinutes == nil || extracted.cookingMinutes! < 0 { missing.append(String(localized: "cooking time")) }
        if extracted.ingredients.isEmpty { missing.append(String(localized: "ingredients")) }
        if extracted.steps.isEmpty { missing.append(String(localized: "steps")) }
        if missing.isEmpty { return String(localized: "Check the extracted recipe before saving.") }
        return String(localized: "Check the extracted recipe before saving. Not found: \(missing.formatted()). Existing values were kept.")
    }
}
