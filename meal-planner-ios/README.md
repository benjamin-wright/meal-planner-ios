# Meal Planner

## Dishes and portions in meals

Saved and planned meals contain components referencing recipes, ready meals, or
ingredients served directly. Each component owns its course, so the same soup
can be a starter in one meal and a main in another. Breakfast, lunch, and dinner
belong to the meal; recipe yield and cooking time, and ready-meal servings and
reheating time, belong to the catalogue entry.

Adding a main, side, starter, or dessert opens a searchable catalogue with a
Recipes/Items switch. Recipes is selected initially and includes recipes and
ready meals; Items contains ingredients. Selecting an ingredient opens a quantity
and unit editor **per person**. For example, a light lunch can include half an
apple, while a hiking lunch can include two apples. Tap an ingredient in a meal
to edit its portion.

In Edit mode, drag the handle beside a dish to change its order or move it to
another course, including an empty course. Use the remove button beside a dish
to delete it. The order and courses are preserved when the meal is reopened.

Components belong to the meal, so the ingredient catalogue needs no serving
defaults. Planning a saved meal copies its components; changing that planned meal
does not change the saved meal. Shopping-list generation scales ingredient
portions by planned servings and combines them with the same ingredients used
in recipes.

This alpha schema uses a fresh named `MealPlanner` store and starts with sample
data. There is no migration from the previous database.

## Keyboard controls

Tap **Hide Keyboard** above the keyboard to finish editing and reveal the rest
of the screen. The control is shared by forms, recipe steps, catalogue searches
and the Shopping List Add sheet.

## Recipe import playground

Open `playgrounds/RecipieImportPlayground.swift`, select the **meal-planner-ios** scheme
and an iOS simulator, then enable **Editor > Canvas > Automatically Refresh Canvas**
and resume the canvas. This setting is per source file; with it disabled a playground
can run while displaying no recorded results. Apple Intelligence must be enabled and ready.

The single playground reads the two adjacent HEIC images in order, prepares them, runs OCR,
and extracts recipe metadata, ingredients and steps in three sequential fresh model sessions.
Edit only `imagePaths` here to try other photos (up to six). Paths resolve relative to
this source file and are available to simulator playgrounds. The canvas exposes original
and prepared images, OCR text, the complete extracted recipe and elapsed time.

Tune the same configuration the app consumes:

- `models/RecipieExtractionService.swift`: image preparation defaults, Vision OCR options,
  focused model instructions, prompts and generation options.
- `models/RecipieImport.swift`: the metadata, ingredients and steps `@Generable` schemas
  and their `@Guide` descriptions. Ingredient quantities are `Double?`; units are required
  strings, with an empty string for unknown units. Unknown quantities and units need review.

The app and playground share image preparation, page ordering and OCR assembly, and the
complete extraction method. The focused extraction methods are also callable individually.
The playground displays original generation errors and uses the feedback workaround below.
It does not save recipes or modify the catalogue. The former comparison playground,
OCR snapshot and simulator experiment screen/scheme have been removed.

### Xcode 27 / iOS 27 model-feedback crash

The assertion at `FoundationModels/LanguageModelFeedback.swift:528` occurs in
Apple's automatic playground feedback formatting. The installed iOS 27.0
(24A434) framework serializes neutral feedback, replaces the exact JSON fragment
`"sentiment" : "neutral",` with a placeholder, then asserts that the placeholder
exists. The crash means that replacement did not find its expected fragment;
the crash report alone does not establish why that particular feedback JSON differs.
A one-word prompt reproduces the assertion, so the recipe prompt, OCR and
`@Generable` schema are not required to trigger it. Apple
[supports Foundation Models in iOS simulator playgrounds](https://developer.apple.com/forums/thread/791768)
and [documents their automatic feedback integration](https://developer.apple.com/forums/thread/791250).

`RecipiePlaygroundSupport.withoutAutomaticModelFeedback` temporarily removes
`XCODE_RUNNING_FOR_PLAYGROUNDS` while awaiting model work, then restores its
original value even if the request throws. The framework checks for the key's
presence; setting it to `0` does not disable the feedback path. Restoring it before
printing or dumping the result preserves ordinary canvas output.

This is an undocumented workaround, applied only to Debug simulator playground
calls. It skips automatic model-feedback capture for those requests; ordinary
model generation and production imports use their existing code. Run model
playgrounds one at a time because the environment is shared by the process.
Remove the wrapper calls when Apple fixes the framework's feedback formatting.
Switching to Legacy Previews Execution is unsuitable: Apple's
[Xcode 26 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-26-release-notes)
list missing playground canvas results in that mode (150811580).

## Creating catalogue entries

Entries created with **Add** inside a picker are selected automatically after
saving, returning to the form that opened the picker. This also works for nested
creation, such as a category created while adding an item. New ingredient dishes
open their per-person quantity and unit editor before being added to the meal.
