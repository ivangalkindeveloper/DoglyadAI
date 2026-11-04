#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "SelectTranscriptParserState",
    ) {
        SelectTranscriptParserPreviewView(
            state: SelectTranscriptParserState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
