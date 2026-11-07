#if DEBUG
    import SwiftUI

    #Preview(
        "01 PhotoViewState",
    ) {
        PhotoViewPreviewView(
            photos: ModulePreviewFactory.photos,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 PhotoViewRemarks",
    ) {
        PhotoViewPreviewView(
            photos: ModulePreviewFactory.photos,
            remarks: ModulePreviewFactory.photoRemarks,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 PhotoViewSavedReport",
    ) {
        PhotoViewPreviewView(
            photos: ModulePreviewFactory.photos,
            remarks: ModulePreviewFactory.photoRemarks,
            isDeletionAvailable: false,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 PhotoViewPortrait",
    ) {
        PhotoViewPreviewView(
            photos: PhotoViewPreviewFactory.portraitPhotos,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 PhotoViewSquare",
    ) {
        PhotoViewPreviewView(
            photos: PhotoViewPreviewFactory.squarePhotos,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
