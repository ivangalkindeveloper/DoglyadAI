import Foundation

final class DSpeechFailingFileManager: FileManager, @unchecked Sendable {
    override func removeItem(
        at _: URL,
    ) throws {
        throw CocoaError(
            .fileWriteNoPermission,
        )
    }
}
