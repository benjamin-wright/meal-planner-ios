# Meal Planner

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

## To Do

### Features

- Add recipies from camera / gallery

### Fixes

- popups like when adding new items in the list view should have a bit of transparency.
- the background border radius on the custom segment picker is tighter than the segment radius.
