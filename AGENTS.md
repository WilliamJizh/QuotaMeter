QuotaMeter is a macOS 14+ SwiftUI menu bar app showing remaining Claude and Codex plan quota. Keep UI state on `@MainActor @Observable` types and non-UI work in actor services/repositories.

The Xcode project, scheme, and source folders are still named `ClaudeMeter` (inherited from the fork); only the built product is `QuotaMeter`. The Swift module is `QuotaMeter`, so tests use `@testable import QuotaMeter`.

Build with `xcodebuild clean build -project ClaudeMeter.xcodeproj -scheme ClaudeMeter -configuration Debug`; test with `xcodebuild test -project ClaudeMeter.xcodeproj -scheme ClaudeMeter -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`.

The project uses file-system-synchronized groups, so adding or deleting Swift files needs no `project.pbxproj` edit.

Usage is read through CLIProxyAPI's `/v0/management/api-call` passthrough, which answers HTTP 200 even when the upstream provider failed — always validate the envelope's inner `status_code`.

The domain model stores consumption (`utilization`), matching what the providers report; the UI counts down via `UsageLimit.remaining`. Status colours stay driven by consumption so an exhausted window is red, not green.

New `AppSettings` keys must persist through `SettingsRepository`, appear in `SettingsView` when user-facing, and decode old saved settings safely.

Menu bar snapshot tests compare with a perceptual tolerance; re-record with `SNAPSHOT_RECORD=1` when icon rendering intentionally changes.
