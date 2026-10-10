import Combine
import Foundation
import WhisperKit

@MainActor
final class DSpeechWhisperKitModel: ObservableObject {
    static let shared = DSpeechWhisperKitModel()

    private static let variant = "large-v3-v20240930_626MB"
    private static let folderKey = "DoglyadSpeech.whisperTurboModelFolder"
    private var model: WhisperKit?
    private var preparationTask: Task<Void, Never>?

    @Published private(set) var state: DSpeechModelPreparation = .checking

    private init() {}

    func prepare() {
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
        prepare()
        let task = preparationTask
        await task?.value
        guard let model else { throw DSpeechError.unavailable }
        return model
    }

    private func prepareModel() async {
        do {
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
            )[
                0,
            ].appendingPathComponent(
                "WhisperKit",
                isDirectory: true,
            )
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
            )
            var backupDirectory = directory
            var backupValues = URLResourceValues()
            backupValues.isExcludedFromBackup = true
            try? backupDirectory.setResourceValues(
                backupValues,
            )

            let cachedFolder = UserDefaults.standard.string(
                forKey: Self.folderKey,
            )
            let folder: URL
            if let cachedFolder, Self.hasModelFiles(
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
                UserDefaults.standard.set(
                    folder.path,
                    forKey: Self.folderKey,
                )
            }

            state = .loading
            model = try await WhisperKit(
                WhisperKitConfig(
                    modelFolder: folder.path,
                    tokenizerFolder: directory,
                    verbose: false,
                    prewarm: false,
                    load: true,
                    download: false,
                ),
            )
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

    private static func hasModelFiles(
        at folder: String,
    ) -> Bool {
        ["AudioEncoder", "TextDecoder", "MelSpectrogram"].allSatisfy { name in
            ["mlmodelc", "mlpackage"].contains { ext in
                let url = URL(
                    fileURLWithPath: folder,
                ).appendingPathComponent(
                    "\(name).\(ext)",
                )
                return FileManager.default.fileExists(
                    atPath: url.path,
                )
            }
        }
    }
}
