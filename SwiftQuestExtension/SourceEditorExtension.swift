import XcodeKit
import os.log

final class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    func extensionDidFinishLaunching() {
        os_log(.default, log: OSLog(subsystem: "com.gabrielnetto.SwiftQuest.XcodeExtension", category: "Extension"), "🚀 SwiftQuest Source Editor Extension DID LAUNCH")
    }
}
