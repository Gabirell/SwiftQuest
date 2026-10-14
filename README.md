# SwiftQuest Xcode Extension

This is a real macOS Xcode Source Editor Extension project for Xcode 26.3+.

## Important

Open `SwiftQuestXcode.xcodeproj` in Xcode. Do **not** open `Package.swift` or treat this directory as a Swift Package.

The project contains two targets:

- `SwiftQuest` - macOS host application
- `SwiftQuestExtension` - Xcode Source Editor Extension

The extension is embedded in the host app under `Contents/PlugIns`.

## First build

1. Open `SwiftQuestXcode.xcodeproj`.
2. Select the `SwiftQuest` scheme.
3. Build and Run.
4. If Xcode asks which app to run for extension testing, choose Xcode for the extension scheme. This is the Apple-supported Source Editor Extension test flow.
5. Enable SwiftQuest under Xcode Settings > Extensions > Xcode Source Editor Extensions.
6. Open a Swift file and use Editor > SwiftQuest > Explain This Swift.

The extension target is configured with `APPLICATION_EXTENSION_API_ONLY = YES` and does not link extension-unsafe AppKit APIs.
