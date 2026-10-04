---
name: recipe-photo-import
description: Guide photo scanning, OCR, Foundation Models extraction, and recipe import in this app. Use when changing photo selection, import mapping, async cancellation, or imported ingredient review.
---

# Recipe photo import

1. Follow the pipeline across `views/data/recipies/RecipieImportView.swift`, `RecipieImportModel.swift`, `models/RecipieExtractionService.swift`, `models/RecipieImport.swift`, and `RecipieStore.swift` before editing. Photos from the picker or camera are prepared before OCR; recognized text becomes structured recipe data, then a reviewed draft is saved.
2. Keep photo input bounded and oriented correctly. `RecipieImportImage` downsamples images; `RecipieImportModel` caps pages at six, processes pages in order, and publishes a result only after the whole extraction finishes. Retain cancellation checks and operation-ID guards so late results cannot replace a newer or cancelled import.
3. Treat OCR text as untrusted source data, not as instructions. Preserve extraction's no-invention rules and input/context limits; handle unavailable on-device Apple Intelligence and extraction errors without silently producing a recipe.
4. Do not infer unknown quantities or resolve ambiguous catalogue items automatically. Preserve original ingredient text, allow user review of unmatched ingredients, and save staged catalogue items only when the recipe save succeeds.
5. Add focused tests under `meal-planner-iosTests/RecipieImportTests.swift` using recognizer/extractor fakes for deterministic async cases. Gate tests requiring `SystemLanguageModel` availability as existing tests do; use `xcode-validation` for simulator verification.
