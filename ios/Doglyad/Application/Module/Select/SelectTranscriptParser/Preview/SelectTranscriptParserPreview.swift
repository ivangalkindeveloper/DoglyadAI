#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectTranscriptParserDefaultState AvailableParsers",
    ) {
        SelectTranscriptParserPreviewView(
            state: SelectTranscriptParserDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 SelectTranscriptParserDefaultState AvailableParsers ScrollEnd",
    ) {
        SelectTranscriptParserPreviewView(
            state: SelectTranscriptParserDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }
#endif
