# Meal Planner

## Recipe experiment in the simulator app

Select the **Recipe Experiment** scheme and an iOS simulator, then press **⌘R**.
The scheme supplies `-recipe-experiment` to open a Debug-only experiment screen
in the normal app process. Select **Run comparison** to run combined extraction,
ingredients-only extraction and steps-only extraction sequentially in fresh sessions.
The screen displays progress, timings, errors and a readable report.

Expand **Input and parameters** to edit the bundled OCR text, temperature and each
variant's instructions. **Reload bundled OCR** restores `playgrounds/RecipieImportOCR.txt`;
rebuild after changing that file on disk. Edits on this screen do not start model requests.
Cancel waits for the current task to unwind before enabling another run.

Use the normal **meal-planner-ios** scheme to return to the usual app. The experiment
screen and comparison runner are excluded from Release builds.

## Recipe import playgrounds

Open `playgrounds/RecipieImportPlayground.swift` in Xcode 26 or later. Select the
`meal-planner-ios` scheme and an iOS simulator, then choose **Editor > Canvas**
and **Resume**. Select either named playground in the canvas.

- **Recipe extraction from text:** edit `playgrounds/RecipieImportOCR.txt` and tune
  `instructions`, `promptPrefix`, or `GenerationOptions`. Each run uses a fresh
  model session and displays the structured recipe and elapsed time. Extraction
  requires Apple Intelligence to be enabled and ready on a supported simulator host;
  the playground prints model availability if it cannot run. Generation failures
  display the original model error, including underlying system errors, rather than
  the app's generic import error.
- **Recipe image preparation and OCR:** the two HEIC photos beside the playground
  are the default test bed: ingredients first, then instructions for
  **10-Min Sticky Ginger Beef Noodles**. Paths resolve relative to the Swift source
  file, so moving the checkout doesn't require changing them. Replace `imagePaths`
  to use other photos in reading order (up to six), or clear it for the generated image.
  The simulator must be able to read those files; device playgrounds cannot read
  files on your Mac. Edit image size, JPEG quality, and OCR options. Expand the
  original/prepared image variables in the canvas and inspect the printed OCR text.
  Set `extractRecipe` to `true` for an end-to-end run, or copy the OCR output into
  `playgrounds/RecipieImportOCR.txt` for faster prompt experiments. That file contains
  a baseline snapshot from the two photos using the default preparation/OCR settings;
  refresh it after changing those settings to keep prompt experiments in sync.

The playgrounds are Debug-only and use the app's existing services and extraction
schema. Experimental overrides live in the playground; normal imports retain their
current defaults. Runs do not save recipes or modify the catalogue. The generated
image is a smoke-test fixture; use real recipe photos to assess extraction quality.

## Combined vs separated extraction experiment

Open `playgrounds/RecipieExtractionComparison.swift` and run its named playground
to compare the existing full recipe extraction with ingredient-only and step-only
schemas. All three calls receive the same complete `RecipieImportOCR.txt`, use
temperature 0, and run sequentially in fresh sessions. Only the focused prompts
and output schemas change; OCR and the app's import implementation are not changed.
The experiment compares ingredient/step extraction, not metadata extraction.
The ingredient-only schema uses a numeric `Double?` quantity to keep unit letters
out of amounts; the combined production schema still uses `String?` quantities.
Its unit is a required string, with an empty string for an unknown unit. Optional
units were being omitted even when an explicit amount was extracted. The simulator
UI test checks `80g`, `15ml soy sauce` and `1 ginger paste sachet (15g)` against their
separate numeric amounts and units, and passes with this experimental schema.
This compares both prompt focus and quantity representation, not prompt focus alone.

The first run's raw report is saved in
`playgrounds/RecipieExtractionComparisonResults.json`. On 8 October 2026, all three
requests failed with `ModelManagerError` code 1026 despite model availability being
reported as available. No output was returned, so this run establishes neither an
accuracy improvement nor a performance advantage. The recorded times are times
to failure, not successful extraction timings. Each rerun prints a readable report
in the canvas for inspection and saving.

## To Do

### Features

- Add recipies from camera / gallery

### Fixes

- popups like when adding new items in the list view should have a bit of transparency.
- the background border radius on the custom segment picker is tighter than the segment radius.
