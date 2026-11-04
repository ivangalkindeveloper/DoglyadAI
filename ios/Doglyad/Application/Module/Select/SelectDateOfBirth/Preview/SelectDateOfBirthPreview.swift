#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "SelectDateOfBirthState",
    ) {
        SelectDateOfBirthPreviewView(
            state: SelectDateOfBirthState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
