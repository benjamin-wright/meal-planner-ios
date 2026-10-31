import Foundation

/// Recover a complete source row when generation copied only its amount column.
/// Ambiguous matches keep the generated quote; quantities and names are never inferred here.
enum RecipieIngredientSourceText {
    static func restoringLine(for ingredient: ExtractedRecipieIngredient, in source: String) -> ExtractedRecipieIngredient {
        let quote = RecipieImportMapper.key(ingredient.sourceText)
        let name = RecipieImportMapper.key(ingredient.name)
        guard !quote.isEmpty, !name.isEmpty, !contains(name, in: quote) else { return ingredient }
        let lines = source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var candidates = Set<String>()
        for (index, line) in lines.enumerated() {
            let normalized = RecipieImportMapper.key(line)
            if hasNameFirstRow(line, name: name, quote: quote) {
                candidates.insert(line)
            }
            // PDF styled runs may put "Onion –" and "1 large, chopped" on separate
            // lines. Require a name-only prefix and an explicit separator, so we
            // cannot attach an amount to the preceding, already complete ingredient.
            guard index + 1 < lines.count,
                  contains(name, in: normalized),
                  !line.contains(where: \.isNumber),
                  line.last.map({ "–—-:".contains($0) }) == true else { continue }
            let next = lines[index + 1]
            guard RecipieImportMapper.key(next) == quote else { continue }
            candidates.insert(line + " " + next)
        }
        guard candidates.count == 1, let line = candidates.first else { return ingredient }
        var result = ingredient
        result.sourceText = line
        return result
    }

    private static func hasNameFirstRow(_ line: String, name: String, quote: String) -> Bool {
        for index in line.indices where "–—-:".contains(line[index]) {
            let next = line.index(after: index)
            // A hyphen within a word (e.g. gluten-free) is not a column separator.
            if line[index] == "-" {
                guard index != line.startIndex, next != line.endIndex,
                      line[line.index(before: index)].isWhitespace, line[next].isWhitespace else { continue }
            }
            let prefix = RecipieImportMapper.key(String(line[..<index]))
            let suffix = RecipieImportMapper.key(String(line[next...]))
            if contains(name, in: prefix), contains(quote, in: suffix) { return true }
        }
        return false
    }

    private static func contains(_ phrase: String, in text: String) -> Bool {
        var remainder = text.startIndex..<text.endIndex
        while let range = text.range(of: phrase, range: remainder) {
            let before = range.lowerBound == text.startIndex ? nil : text[text.index(before: range.lowerBound)]
            let after = range.upperBound == text.endIndex ? nil : text[range.upperBound]
            if before.map({ !$0.isLetter && !$0.isNumber }) ?? true,
               after.map({ !$0.isLetter && !$0.isNumber }) ?? true { return true }
            remainder = text.index(after: range.lowerBound)..<text.endIndex
        }
        return false
    }
}
