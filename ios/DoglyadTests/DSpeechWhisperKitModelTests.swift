@testable import DoglyadSpeech
import Foundation
import Testing

@MainActor
struct DSpeechWhisperKitModelTests {
    private let folderKey = "DoglyadSpeech.whisperTurboModelFolder"

    @Test
    func availabilityRequiresAllDownloadedModelComponents() async throws {
        try await withStore { model, directory, defaults in
            #expect(
                !model.isDownloaded,
            )
            let folder = directory.appendingPathComponent(
                "model",
            )
            defaults.set(
                folder.path,
                forKey: folderKey,
            )
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent(
                    "AudioEncoder.mlmodelc",
                ),
                withIntermediateDirectories: true,
            )
            #expect(
                !model.isDownloaded,
            )
            try writeModel(
                in: directory,
                defaults: defaults,
            )
            #expect(
                model.isDownloaded,
            )
        }
    }

    @Test
    func deletionRemovesModelAndTokenizerButPreservesOtherData() async throws {
        try await withStore { model, directory, defaults in
            try writeModel(
                in: directory,
                defaults: defaults,
            )
            let tokenizer = directory.appendingPathComponent(
                "tokenizer.json",
            )
            try Data(
                "{}".utf8,
            ).write(
                to: tokenizer,
            )
            let unrelated = directory.deletingLastPathComponent().appendingPathComponent(
                "unrelated.txt",
            )
            try Data(
                "Keep".utf8,
            ).write(
                to: unrelated,
            )
            defaults.set(
                "Keep",
                forKey: "unrelated",
            )
            try await model.deleteDownloadedModel()
            #expect(
                !model.isDownloaded,
            )
            #expect(
                !FileManager.default.fileExists(
                    atPath: directory.path,
                ),
            )
            #expect(
                defaults.string(
                    forKey: folderKey,
                ) == nil,
            )
            #expect(
                defaults.string(
                    forKey: "unrelated",
                ) == "Keep",
            )
            #expect(
                FileManager.default.fileExists(
                    atPath: unrelated.path,
                ),
            )
            #expect(
                model.state == .checking,
            )
            try await model.deleteDownloadedModel()
        }
    }

    @Test
    func failedDeletionPropagatesErrorAndKeepsModelAvailableForRetry() async throws {
        try await withStore(
            fileManager: DSpeechFailingFileManager(),
        ) { model, directory, defaults in
            try writeModel(
                in: directory,
                defaults: defaults,
            )
            let storedFolder = defaults.string(
                forKey: folderKey,
            )
            await #expect(
                throws: CocoaError.self,
            ) {
                try await model.deleteDownloadedModel()
            }
            #expect(
                model.isDownloaded,
            )
            #expect(
                defaults.string(
                    forKey: folderKey,
                ) == storedFolder,
            )
            await #expect(
                throws: CocoaError.self,
            ) {
                try await model.deleteDownloadedModel()
            }
        }
    }

    @Test
    func cancelledDeletionKeepsFilesAndStoredPath() async throws {
        try await withStore { model, directory, defaults in
            try writeModel(
                in: directory,
                defaults: defaults,
            )
            let task = Task {
                try await model.deleteDownloadedModel()
            }
            task.cancel()
            await #expect(
                throws: CancellationError.self,
            ) {
                try await task.value
            }
            #expect(
                model.isDownloaded,
            )
            #expect(
                defaults.string(
                    forKey: folderKey,
                ) != nil,
            )
        }
    }

    private func withStore(
        fileManager: FileManager = .default,
        _ execute: (DSpeechWhisperKitModel, URL, UserDefaults) async throws -> Void,
    ) async throws {
        let suite = "doglyad.tests.speech.\(UUID())"
        let defaults = try #require(
            UserDefaults(
                suiteName: suite,
            ),
        )
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            suite,
            isDirectory: true,
        )
        defer {
            defaults.removePersistentDomain(
                forName: suite,
            )
            try? FileManager.default.removeItem(
                at: root,
            )
        }
        let directory = root.appendingPathComponent(
            "WhisperKit",
            isDirectory: true,
        )
        let model = DSpeechWhisperKitModel(
            directory: directory,
            defaults: defaults,
            fileManager: fileManager,
        )
        try await execute(
            model,
            directory,
            defaults,
        )
    }

    private func writeModel(
        in directory: URL,
        defaults: UserDefaults,
    ) throws {
        let folder = directory.appendingPathComponent(
            "model",
            isDirectory: true,
        )
        for component in ["AudioEncoder", "TextDecoder", "MelSpectrogram"] {
            try FileManager.default.createDirectory(
                at: folder.appendingPathComponent(
                    "\(component).mlmodelc",
                    isDirectory: true,
                ),
                withIntermediateDirectories: true,
            )
        }
        defaults.set(
            folder.path,
            forKey: folderKey,
        )
    }
}
