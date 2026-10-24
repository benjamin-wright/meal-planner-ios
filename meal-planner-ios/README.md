# Meal Planner

## Dishes and portions in meals

Saved and planned meals contain components referencing recipes, ready meals, or
ingredients served directly. Each component owns its course, so the same soup
can be a starter in one meal and a main in another. Breakfast, lunch, and dinner
belong to the meal; recipe yield and cooking time, and ready-meal servings and
reheating time, belong to the catalogue entry.

**Add dish** opens a searchable catalogue with a course picker and a
Recipes/Items switch. The course starts at Main. Recipes is selected initially and
includes recipes and ready meals; Items contains ingredients. Selecting an ingredient opens a quantity
and unit editor **per person**. For example, a light lunch can include half an
apple, while a hiking lunch can include two apples. Open the dish menu and choose
**Edit Portion** to change its quantity or unit.

Dishes appear in Starter, Main, Side, Dessert order, with a course tag on each row.
The dish menu lets you change its course or delete it; planned recipes also offer
**Substitute Ingredients**. Dishes keep their relative order within each course.
There is no separate reordering mode, and changes are saved with the meal.

Components belong to the meal, so the ingredient catalogue needs no serving
defaults. Planning a saved meal copies its components; changing that planned meal
does not change the saved meal. Shopping-list generation scales ingredient
portions by planned servings and combines them with the same ingredients used
in recipes.

This alpha schema uses a fresh named `MealPlanner` store and starts with sample
data. There is no migration from the previous database.

Count, grams and litres are permanent base units. They cannot be changed or
deleted; custom units remain editable. Existing stores adopt unchanged sample
units and add any missing bases without changing custom units or their references.
New quantities and ready-meal shopping entries use the base count unit. If a
preferred custom weight or volume unit changes dimension, settings fall back to
the corresponding base unit.

## Planning dinners

Each day keeps its own row and day badge. Drag a dinner's meal name onto another
day. Dropping onto an empty day moves the dinner and leaves its
old day empty; dropping onto an occupied day swaps the two dinners. Other days
keep their meals.

Open the dinner's ellipsis menu and choose **Edit** to change its details.
The menu also offers **Delete** and the same movement actions under
**Move to…**, with **Move to** or **Swap with** labels for each destination.
Moves, swaps and deletions are saved immediately.

## Keyboard controls

Tap **Hide Keyboard** above the keyboard to finish editing and reveal the rest
of the screen. The control is shared by forms, recipe steps, catalogue searches
and the Shopping List Add sheet.

## Recipe photo import

Ingredient-only photos are supported: absent cooking instructions produce no
steps, and ingredient rows are never meant to become a method. Imported names
use a short dish title (ideally 2–6 words, limited to 60 characters). A brief
description may be synthesized from the title and ingredients.

Servings must be explicitly stated as people or portions. Automatic import accepts
1–24; absent, ambiguous or larger counts keep the current draft value and are
flagged for review, rather than guessed or clamped. Ingredient weights such as
750 g are not serving counts. Servings and cooking times also need a source quote
found in the photo text; numeric serving counts must agree with that quote.
Larger recipes can still be entered manually.

Photo imports first match unique exact ingredient names. For all other names,
including small spelling differences, the app ranks up to 50 existing ingredients by
normalized edit similarity and word overlap, then asks the on-device model to
choose an equivalent ingredient using those names, scores, the original line and
recipe title. This allows “cheddar” to match “cheddar cheese”, and “beef” in
bolognese to favour “beef mince” over “beef steak”. Explicit ingredient details
take priority over the title; ambiguous matches remain unresolved when there is
not enough context. Scores are lexical similarity,
not confidence; the model can leave a line unmatched and must not substitute a
different ingredient or prepared dish. Duplicate names, failed model requests and
uncertain matches remain available for manual review. Original text, quantities
and units are preserved, and nothing is saved until the import is reviewed.
Accepted matches can be reviewed at a glance; opening each ingredient is optional.

`models/RecipieIngredientMatching.swift` owns ranking, candidate selection and
matching instructions. Each unresolved line uses a fresh model session; unique
exact matches do not need an additional model request. Similar spelling alone
cannot accept a match: “oat milk” must not automatically become “goat milk”.

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

## Test plans and UI fixtures

Domain rules live outside views and persistence adapters. `IngredientResolver` owns
ingredient and substitution validity; `IngredientDependencies` owns their reference
policy. `UnitDefinition` handles unit calculation and formatting as plain values.
`ShoppingListCalculator` consumes a value snapshot and produces entries, while
`ShoppingListStore` loads and saves them. `ShoppingListCompletion` owns delayed
removal and undo, with a controllable clock for tests.

Each picker or staged editor has its own `FlowRouter.Session`, including its return
destination and completion. Planned extras and direct shopping entries share
`CatalogEntryDraft` and `CatalogEntryFields`, while their screens choose where to
save. Both meal editors use `MealComponentsForm` for their details, dish list and save actions.

The shared scheme has three explicit test plans:

- **Deterministic** (default): domain and SwiftData tests, plus functional UI journeys.
- **Platform Integration**: live Vision OCR and Foundation Models checks. Model checks
  require Apple Intelligence and report as skipped when it is unavailable.
- **Launch Diagnostics**: launch screenshots and launch performance measurements.

The default plan keeps full deterministic verification in one pass. Select a
specific suite for focused iterations. Platform Integration and Launch Diagnostics
remain separate because they require platform services or measure startup.

Each UI test receives its own temporary on-disk store. Relaunches within that test
reuse the same store, so they still verify persistence. The standard fixture is the
sample catalogue and plan. A stale-shopping-list
fixture verifies regeneration by replacing an old entry with the current plan's entries.
Fixture selection is confined to Debug app composition. Views, stores, timers and gestures
run normally; cancellation and deadline combinations are tested with the domain clock,
while the UI checks automatic removal and Undo without racing the removal deadline.

Use `MealPlannerUITestCase.launchInPortrait` (or `launch` when testing UI configurations)
to preserve this isolation. Do not use the Settings Reset action as general test setup.
Keep combinatorial rules in domain tests and persistence contracts in real SwiftData
tests. Group related UI checks into journeys that share an app launch and setup, with
named `XCTContext` activities marking their stages. Keep separate journeys when they
need a different fixture or launch configuration; keep relaunches that verify persistence.
The domain target uses one test runner rather than creating parallel simulator clones.
Run parameterized suites as a whole when using Xcode automation: selecting individual
methods can retain a single argument selection and omit the rest of the matrix.
