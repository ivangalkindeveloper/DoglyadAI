#if DEBUG
    import Combine
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 WebDocumentLoadingState LoadingDocument",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 WebDocumentLoadingState LoadingDocument ScrollEnd",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentLoadingState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "03 WebDocumentSuccessState PrivacyPolicy",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentSuccessState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 WebDocumentSuccessState PrivacyPolicy ScrollEnd",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentSuccessState(),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "05 WebDocumentSuccessState TermsAndConditions",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentSuccessState(),
            document: .termsAndConditions,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 WebDocumentSuccessState TermsAndConditions ScrollEnd",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentSuccessState(),
            document: .termsAndConditions,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
        .previewScrollToEnd()
    }

    #Preview(
        "07 WebDocumentErrorState DocumentRequestFailed",
    ) {
        WebDocumentPreviewView(
            state: WebDocumentErrorState(
                error: URLError(
                    .notConnectedToInternet,
                ),
            ),
        ).previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
