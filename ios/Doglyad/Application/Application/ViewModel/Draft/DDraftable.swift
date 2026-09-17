import Combine

@MainActor
protocol DDraftable: AnyObject {
    associatedtype Draft
    associatedtype DraftSnapshot

    var draftAutosaver: DDraftAutosaver<DraftSnapshot> { get }

    func loadDraft() async -> Draft?

    func applyDraft(
        _ draft: Draft
    )

    func clearDraft() async

    func makeDraftSnapshot() -> DraftSnapshot

    func saveDraftSnapshot(
        _ draft: DraftSnapshot
    ) async

    func draftChangePublishers() -> [AnyPublisher<Void, Never>]
}

extension DDraftable {
    func restoreDraft() async -> Bool {
        guard let draft = await loadDraft() else { return false }

        applyDraft(draft)
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
                await self.saveDraftSnapshot(draft)
            }
        )
    }

    func stopDraftAutosave() {
        draftAutosaver.stop()
    }

    func flushPendingDraftSave() {
        draftAutosaver.flush()
    }

    func waitForPendingDraftSave() async {
        await draftAutosaver.waitForPendingSave()
    }
}
