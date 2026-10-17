import Combine
import Foundation

@MainActor
final class DraftAutosaver<Draft> {
    private let delay: RunLoop.SchedulerTimeType.Stride
    private var cancellables = Set<AnyCancellable>()
    private var writeTask: Task<Void, Never>?
    private var pendingWrites: [() async throws -> Void] = []
    private var lastError: Error?
    private var isPendingChangesPresent = false
    private var makeDraft: (() -> Draft?)?
    private var saveDraft: ((Draft) async throws -> Void)?
    private var onFailure: ((Error) -> Void)?

    init(
        delay: RunLoop.SchedulerTimeType.Stride = .seconds(
            1,
        ),
    ) {
        self.delay = delay
    }

    func start(
        publishers: [AnyPublisher<Void, Never>],
        makeDraft: @escaping () -> Draft?,
        saveDraft: @escaping (Draft) async throws -> Void,
        onFailure: @escaping (Error) -> Void,
    ) {
        stop()
        self.makeDraft = makeDraft
        self.saveDraft = saveDraft
        self.onFailure = onFailure
        Publishers.MergeMany(
            publishers,
        )
        .handleEvents(
            receiveOutput: { [weak self] in self?.isPendingChangesPresent = true },
        )
        .debounce(
            for: delay,
            scheduler: RunLoop.main,
        )
        .sink { [weak self] _ in self?.savePendingDraft() }
        .store(
            in: &cancellables,
        )
    }

    func flush() {
        savePendingDraft()
        startWritingIfNeeded()
    }

    func enqueue(
        operation: @escaping () async throws -> Void,
    ) {
        pendingWrites.append(
            operation,
        )
        startWritingIfNeeded()
    }

    func stop() {
        savePendingDraft()
        cancellables.removeAll()
        makeDraft = nil
        saveDraft = nil
    }

    func waitForPendingSave() async throws {
        startWritingIfNeeded()
        await writeTask?.value
        if let lastError { throw lastError }
    }

    private func startWritingIfNeeded() {
        guard writeTask == nil, !pendingWrites.isEmpty else { return }
        writeTask = Task { [weak self] in
            guard let self else { return }
            defer { writeTask = nil }
            while let operation = pendingWrites.first {
                do {
                    try await operation()
                    pendingWrites.removeFirst()
                    lastError = nil
                } catch {
                    lastError = error
                    onFailure?(
                        error,
                    )
                    return
                }
            }
        }
    }

    private func savePendingDraft() {
        guard isPendingChangesPresent, let draft = makeDraft?(), let saveDraft else { return }
        isPendingChangesPresent = false
        enqueue { try await saveDraft(
            draft,
        ) }
    }
}
