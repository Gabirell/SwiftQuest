import XcodeKit

final class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    func extensionDidFinishLaunching() {
        // SwiftQuest is ready to receive source-editor commands.
    }

    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey : Any]] {
        [
            [
                .classNameKey: "SourceEditorCommand",
                .identifierKey: "com.gabrielnetto.SwiftQuest.explain",
                .nameKey: "Explain This Swift"
            ]
        ]
    }
}
