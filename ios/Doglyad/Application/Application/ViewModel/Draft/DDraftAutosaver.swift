import Combine
import Foundation

@MainActor
final class DDraftAutosaver<Draft> {
    private let delay: RunLoop.SchedulerTimeType.Stride
    private var cancellables = Set<AnyCancellable>()
    private var writeTask: Task<Void, Never>?
    private var hasPendingChanges = false
    private var makeDraft: (() -> Draft?)?
    private var saveDraft: ((Draft) async -> Void)?

    init(
        delay: RunLoop.SchedulerTimeType.Stride = .seconds(1)
    ) {
        self.delay = delay
    }

    func start(
        publishers: [AnyPublisher<Void, Never>],
        makeDraft: @escaping () -> Draft?,
        saveDraft: @escaping (Draft) async -> Void
    ) {
        stop()
        self.makeDraft = makeDraft
        self.saveDraft = saveDraft

        Publishers.MergeMany(publishers)
            .handleEvents(
                receiveOutput: { [weak self] in
                    self?.hasPendingChanges = true
                }
            )
            .debounce(
                for: delay,
                scheduler: RunLoop.main
            )
            .sink { [weak self] _ in
                self?.savePendingDraft()
            }
            .store(in: &cancellables)
    }

    func flush() {
        savePendingDraft()
    }

    func enqueue(
        operation: @escaping () async -> Void
    ) {
        let previousTask = writeTask
        writeTask = Task {
            await previousTask?.value
            guard !Task.isCancelled else { return }

            await operation()
        }
    }

    func stop() {
        cancellables.removeAll()
        hasPendingChanges = false
        makeDraft = nil
        saveDraft = nil
    }

    func waitForPendingSave() async {
        await writeTask?.value
        writeTask = nil
    }

    private func savePendingDraft() {
        guard hasPendingChanges,
              let draft = makeDraft?(),
              let saveDraft
        else {
            return
        }

        hasPendingChanges = false
        enqueue {
            await saveDraft(draft)
        }
    }
}
