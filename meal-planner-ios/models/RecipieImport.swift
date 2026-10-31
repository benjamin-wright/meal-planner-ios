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
    /// Catalogue choices keyed by the original extracted ingredient index.
    var matchedItemIDs: [Int: UUID] = [:]
}

@Generable
struct ExtractedRecipieMetadata: Equatable {
    @Guide(description: "True for a recipe or an ingredient list for a dish, even when cooking instructions are absent. False for unrelated text.")
    var isRecipe: Bool
    @Guide(description: "Short dish name, ideally 2–6 words and at most 60 characters. Keep the core source title, omitting taglines, ingredients lists, quantities and serving counts. If untitled, use a simple descriptive name supported by the ingredients, or null if unclear.")
    var name: String?
    @Guide(description: "One short sentence describing the dish, based on the source title and ingredients, or null. A brief synthesized description is fine; do not invent cooking methods, dietary claims, timings or servings.")
    var summary: String?
    @Guide(description: "Exact quote of the serving statement, including its label, such as 'Serves 4' or 'Makes 6 portions'. Null when absent; never quote ingredient quantities or invent a statement.")
    var servingsSourceText: String?
    @Guide(description: "Explicit number of people or portions served, from 1 to 24. Use null if missing, ambiguous or outside this range. Never use ingredient amounts, weights such as 750g, millilitres, calories, temperatures, minutes or counts of individual ingredients as servings. Do not estimate or clamp.")
    var serves: Int?
    @Guide(description: "Exact quote stating the cooking time and its label, or null when absent. Do not quote a preparation time or invent a statement.")
    var cookingTimeSourceText: String?
    @Guide(description: "Explicit cooking time in minutes, or null if absent. Never substitute preparation time or use 0 for missing time.")
    var cookingMinutes: Int?
}

@Generable
struct ExtractedRecipieIngredients {
    @Guide(description: "One entry per ingredient. Join ingredient lines wrapped across several OCR lines (e.g. 2 fine egg / noodle nests is one ingredient). Names may come before amounts or in a separate table column. Skip allergen codes, page references and other labels that are not ingredients, such as A1,A3. Simplify only the name field; sourceText must retain the complete original row including preparations.")
    var ingredients: [ExtractedRecipieIngredient]
}

@Generable
struct ExtractedRecipieIngredient: Equatable, Encodable {
    @Guide(description: "Complete original ingredient row, including the ingredient name, amount, unit and preparation notes, preserving spelling and order. Join wrapped lines or table columns belonging to this row. For 'Tomato purée – 2 tablespoons', return the whole row, never just '2 tablespoons'.")
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
    @Guide(description: "Only explicit cooking instructions. Return an empty array when the source is just ingredients or has no method. Never copy ingredient rows into steps or turn chopped/diced/grated ingredient descriptions into instructions. Join wrapped lines belonging to one action; keep distinct actions separate, in order, with original wording, temperatures and times.")
    var steps: [String]
}

/// Automatic import limits only; people can still enter larger recipes manually.
enum RecipieImportMetadataRules {
    static func name(_ value: String?) -> String? {
        guard let value else { return nil }
        let name = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty else { return nil }
        guard name.count > 60 else { return name }
        let prefix = String(name.prefix(60))
        // Avoid cutting the final word, unless the title is one unusually long word.
        if name[name.index(name.startIndex, offsetBy: 60)] == " " { return prefix }
        if let space = prefix.lastIndex(of: " ") { return String(prefix[..<space]) }
        return prefix
    }

    static func servings(_ value: Int?) -> Int? {
        guard let value, (1...24).contains(value) else { return nil }
        return value
    }

    static func isSourceQuote(_ quote: String?, in source: String) -> Bool {
        guard let quote else { return false }
        let normalized = RecipieImportMapper.key(quote)
        // Bare numbers are not evidence: the quote must include the original label/unit.
        guard !normalized.isEmpty, normalized.contains(where: \.isLetter) else { return false }
        let text = RecipieImportMapper.key(source)
        var searchRange = text.startIndex..<text.endIndex
        while let match = text.range(of: normalized, range: searchRange) {
            let before = match.lowerBound == text.startIndex ? nil : text[text.index(before: match.lowerBound)]
            let after = match.upperBound == text.endIndex ? nil : text[match.upperBound]
            if before.map({ !$0.isLetter && !$0.isNumber }) ?? true,
               after.map({ !$0.isLetter && !$0.isNumber }) ?? true { return true }
            searchRange = text.index(after: match.lowerBound)..<text.endIndex
        }
        return false
    }

    static func validated(_ metadata: ExtractedRecipieMetadata, source: String) -> ExtractedRecipieMetadata {
        var result = metadata
        result.name = name(metadata.name)
        result.serves = isSourceQuote(metadata.servingsSourceText, in: source) ? servings(metadata.serves) : nil
        if let serves = result.serves, let quote = metadata.servingsSourceText {
            let numbers = quote.split(whereSeparator: { !$0.isNumber })
            // Reject ranges and conflicting numbers; spelled-out counts still use the model's interpretation.
            if !numbers.isEmpty && (numbers.count != 1 || Int(numbers[0]) != serves) {
                result.serves = nil
            }
        }
        if !isSourceQuote(metadata.cookingTimeSourceText, in: source) {
            result.cookingMinutes = nil
        }
        return result
    }
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
        guard let itemID, let unitID, let quantity = quantity(units: units) else { return false }
        return (try? IngredientResolver(items: items, units: units).resolve(
            RecipieIngredientDraft(id: id, itemID: itemID, unitID: unitID, quantity: quantity)
        )) != nil
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

    static func ingredient(_ extracted: ExtractedRecipieIngredient, items: [Item], units: [Unit],
                           matchedItemID: UUID? = nil) -> ImportedRecipieIngredient {
        let catalogue = RecipieIngredientMatching.catalogue(from: items)
        let exactID = RecipieIngredientMatching.exactMatch(for: extracted.name, in: catalogue)
        let selected = catalogue.first { $0.itemID == matchedItemID }
        let validatedID = selected.flatMap { candidate in
            catalogue.filter { key($0.name) == key(candidate.name) }.count == 1 ? candidate.itemID : nil
        }
        let quantityText = extracted.quantity.flatMap { amount in
            guard amount.isFinite, amount > 0 else { return nil as String? }
            return amount.formatted(.number.locale(Locale(identifier: "en_US_POSIX"))
                .grouping(.never).precision(.significantDigits(1...17)))
        } ?? ""
        let sourceUnit = extracted.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ImportedRecipieIngredient(
            sourceText: extracted.sourceText, name: extracted.name,
            quantityText: quantityText, itemID: validatedID ?? exactID
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
            return units.filter { $0.isBaseUnit && $0.unitType == .count }.map { ($0, nil) }
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
        if let name = RecipieImportMetadataRules.name(extracted.name) {
            draft.name = name
        }
        if let summary = extracted.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            draft.summary = summary
        }
        if let serves = RecipieImportMetadataRules.servings(extracted.serves) { draft.serves = serves }
        if let time = extracted.cookingMinutes, time >= 0 { draft.time = time }
        if !extracted.ingredients.isEmpty {
            draft.importedIngredients = extracted.ingredients.enumerated().compactMap { index, value in
                guard isPlausibleIngredient(value) else { return nil }
                return ingredient(value, items: items, units: units, matchedItemID: extracted.matchedItemIDs[index])
            }
            draft.ingredients = []
        }
        let steps = extracted.steps.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !steps.isEmpty { draft.steps = steps }
    }

    static func reviewMessage(for extracted: ExtractedRecipie) -> String {
        var missing: [String] = []
        if extracted.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { missing.append(String(localized: "name")) }
        if RecipieImportMetadataRules.servings(extracted.serves) == nil { missing.append(String(localized: "servings")) }
        if extracted.cookingMinutes == nil || extracted.cookingMinutes! < 0 { missing.append(String(localized: "cooking time")) }
        if extracted.ingredients.isEmpty { missing.append(String(localized: "ingredients")) }
        if extracted.steps.isEmpty { missing.append(String(localized: "steps")) }
        if missing.isEmpty { return String(localized: "Check the extracted recipe before saving.") }
        return String(localized: "Check the extracted recipe before saving. Needs review: \(missing.formatted()). Existing values were kept.")
    }
}
