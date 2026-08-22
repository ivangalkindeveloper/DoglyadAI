import Foundation
import SwiftUI

@MainActor
final class RecievedConclusionMarkdownViewModel: ObservableObject {
    @Published private(set) var displayedResponse = ""

    private let response: String
    private var nextWordIndex = 0
    private var isAnimating = false

    init(
        response: String
    ) {
        self.response = response
    }

    func animateResponse() async {
        guard !isAnimating else { return }

        isAnimating = true
        defer { isAnimating = false }

        let words = response.components(separatedBy: " ")
        while nextWordIndex < words.count {
            guard !Task.isCancelled else { return }

            let separator = nextWordIndex == 0 ? "" : " "
            let word = words[nextWordIndex]
            withAnimation(.easeIn(duration: 0.3)) {
                displayedResponse.append(separator + word)
            }
            nextWordIndex += 1

            guard nextWordIndex < words.count else { return }
            do {
                try await Task.sleep(nanoseconds: 60000000)
            } catch {
                return
            }
        }
    }
}
