import Combine
import Foundation
import WhisperKit

@MainActor
public final class DSpeechWhisperKitModel: ObservableObject {
    public static let shared = DSpeechWhisperKitModel()

    private static let variant = "large-v3-v20240930_626MB"
    private static let folderKey = "DoglyadSpeech.whisperTurboModelFolder"
    private let directory: URL
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private var model: WhisperKit?
    private var preparationTask: Task<Void, Never>?
    private var isDeletingModel = false

    @Published public private(set) var state: DSpeechModelPreparationStatus = .checking

    init(
        directory: URL? = nil,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
    ) {
        self.directory = directory ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
        )[
            0,
        ].appendingPathComponent(
            "WhisperKit",
            isDirectory: true,
        )
        self.defaults = defaults
        self.fileManager = fileManager
    }

    public var isDownloaded: Bool {
        if model != nil { return true }
        guard let folder = defaults.string(
            forKey: Self.folderKey,
        ) else { return false }
        return hasModelFiles(
            at: folder,
        )
    }

    public func deleteDownloadedModel() async throws {
        try Task.checkCancellation()
        guard !isDeletingModel else { throw DSpeechError.unavailable }
        isDeletingModel = true
        defer { isDeletingModel = false }

        let preparation = preparationTask
        preparation?.cancel()
        await preparation?.value
        try Task.checkCancellation()

        do {
            try fileManager.removeItem(
                at: directory,
            )
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            // An already absent model is a successful, idempotent deletion.
        }
        await model?.unloadModels()
        model = nil
        defaults.removeObject(
            forKey: Self.folderKey,
        )
        state = .checking
    }

    func prepare() {
        guard !isDeletingModel else { return }
        if model != nil {
            state = .ready
            return
        }
        guard preparationTask == nil else { return }

        state = .checking
        preparationTask = Task { [weak self] in
            guard let self else { return }
            await prepareModel()
        }
    }

    func load() async throws -> WhisperKit {
        try Task.checkCancellation()
        guard !isDeletingModel else { throw DSpeechError.unavailable }
        prepare()
        let task = preparationTask
        await task?.value
        try Task.checkCancellation()
        guard !isDeletingModel, let model else { throw DSpeechError.unavailable }
        return model
    }

    private func prepareModel() async {
        do {
            try Task.checkCancellation()
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
            )
            var backupDirectory = directory
            var backupValues = URLResourceValues()
            backupValues.isExcludedFromBackup = true
            try? backupDirectory.setResourceValues(
                backupValues,
            )

            let cachedFolder = defaults.string(
                forKey: Self.folderKey,
            )
            let folder: URL
            if let cachedFolder, hasModelFiles(
                at: cachedFolder,
            ) {
                folder = URL(
                    fileURLWithPath: cachedFolder,
                )
            } else {
                state = .downloading(
                    progress: nil,
                )
                folder = try await WhisperKit.download(
                    variant: Self.variant,
                    downloadBase: directory,
                    progressCallback: { progress in
                        let fraction = progress.totalUnitCount > 0
                            ? min(
                                max(
                                    progress.fractionCompleted,
                                    0,
                                ),
                                1,
                            )
                            : nil
                        Task { @MainActor in
                            DSpeechWhisperKitModel.shared.updateProgress(
                                fraction,
                            )
                        }
                    },
                )
                try Task.checkCancellation()
                defaults.set(
                    folder.path,
                    forKey: Self.folderKey,
                )
            }

            state = .loading
            let loadedModel = try await WhisperKit(
                WhisperKitConfig(
                    modelFolder: folder.path,
                    tokenizerFolder: directory,
                    verbose: false,
                    prewarm: false,
                    load: true,
                    download: false,
                ),
            )
            try Task.checkCancellation()
            model = loadedModel
            state = .ready
        } catch {
            state = .failed
        }
        preparationTask = nil
    }

    private func updateProgress(
        _ fraction: Double?,
    ) {
        guard case let .downloading(
            previous,
        ) = state else { return }
        if let fraction, let previous, fraction < previous + 0.01, fraction < 1 {
            return
        }
        state = .downloading(
            progress: fraction,
        )
    }

    private func hasModelFiles(
        at folder: String,
    ) -> Bool {
        ["AudioEncoder", "TextDecoder", "MelSpectrogram"].allSatisfy { name in
            ["mlmodelc", "mlpackage"].contains { ext in
                let url = URL(
                    fileURLWithPath: folder,
                ).appendingPathComponent(
                    "\(name).\(ext)",
                )
                return fileManager.fileExists(
                    atPath: url.path,
                )
            }
        }
    }
}
