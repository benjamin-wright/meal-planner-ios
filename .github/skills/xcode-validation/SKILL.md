---
name: xcode-validation
description: Verify changes to this iOS Xcode project with its existing build, Swift Testing, and XCTest UI targets. Use when building, testing, reviewing results, or working from a Linux cloud agent.
---

# Xcode validation

1. Work from the repository root. The shared project scheme is `meal-planner-ios` in `meal-planner-ios.xcodeproj`; the app targets iOS 26 and uses Apple-only SwiftUI, SwiftData, Vision, and Foundation Models APIs. There is no Swift Package manifest or separate Linux test suite.
2. On a Mac with a compatible Xcode and iOS 26 simulator installed, discover an available simulator with `xcrun simctl list devices available`. Build with `xcodebuild -project meal-planner-ios.xcodeproj -scheme meal-planner-ios -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`. Run tests with `xcodebuild -project meal-planner-ios.xcodeproj -scheme meal-planner-ios -destination 'platform=iOS Simulator,id=<available-device-UDID>' CODE_SIGNING_ALLOWED=NO test` (replace the placeholder with an actual simulator ID).
3. The shared scheme includes `meal-planner-iosTests` (Swift Testing, `@Test` / `#expect`) and `meal-planner-iosUITests` (XCTest). Run the relevant target or test cases when narrowing a failure, then verify the full scheme when possible. Some Foundation Models tests depend on Apple Intelligence availability; check their existing gates rather than assuming they always run.
4. GitHub cloud agents commonly run on Linux, where `xcodebuild`, iOS SDKs, and the simulator are unavailable. Do not claim a successful iOS build or test from Linux `swift` alone. Review the changed code and project references, run only checks actually supported in the environment, and state explicitly which Xcode checks still need to run on macOS. Do not add an unsupported macOS runner to the cloud agent setup to work around this limitation.
