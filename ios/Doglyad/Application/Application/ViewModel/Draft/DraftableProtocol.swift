import Combine

@MainActor
protocol DraftableProtocol: AnyObject {
    associatedtype Draft
    associatedtype DraftSnapshot

    var draftAutosaver: DraftAutosaver<DraftSnapshot> { get }

    func loadDraft() async throws -> Draft?

    func applyDraft(
        _ draft: Draft,
    )

    func clearDraft() async throws

    func makeDraftSnapshot() -> DraftSnapshot

    func saveDraftSnapshot(
        _ draft: DraftSnapshot,
    ) async throws

    func onDraftSaveFailed(
        _ error: Error,
    )

    func draftChangePublishers() -> [AnyPublisher<Void, Never>]
}

extension DraftableProtocol {
    func restoreDraft() async throws -> Bool {
        guard let draft = try await loadDraft() else { return false }

        applyDraft(
            draft,
        )
        return true
    }

    func startDraftAutosave() {
        draftAutosaver.start(
            publishers: draftChangePublishers(),
            makeDraft: { [weak self] in
                self?.makeDraftSnapshot()
            },
            saveDraft: { [weak self] draft in
                guard let self else { return }
                try await saveDraftSnapshot(
                    draft,
                )
            },
            onFailure: { [weak self] error in self?.onDraftSaveFailed(
                error,
            ) },
        )
    }

    func stopDraftAutosave() {
        draftAutosaver.stop()
    }

    func flushPendingDraftSave() {
        draftAutosaver.flush()
    }

    func waitForPendingDraftSave() async throws {
        try await draftAutosaver.waitForPendingSave()
    }
}
