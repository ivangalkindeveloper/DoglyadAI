#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectTranscriptParserState",
    ) {
        SelectTranscriptParserPreviewView(
            state: SelectTranscriptParserState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
