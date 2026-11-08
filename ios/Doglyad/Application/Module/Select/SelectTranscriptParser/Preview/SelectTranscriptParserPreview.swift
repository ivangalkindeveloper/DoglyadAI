#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 SelectTranscriptParserDefaultState",
    ) {
        SelectTranscriptParserPreviewView(
            state: SelectTranscriptParserDefaultState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
