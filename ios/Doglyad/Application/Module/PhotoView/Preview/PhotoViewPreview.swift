#if DEBUG
    import SwiftUI

    #Preview(
        "01 PhotoViewInitialState LandscapePhoto",
    ) {
        PhotoViewPreviewView(
            photos: ModulePreviewFactory.photos,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 PhotoViewInitialState ModelRemarks",
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
        "03 PhotoViewInitialState SavedReportReadOnly",
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
        "04 PhotoViewInitialState PortraitPhoto",
    ) {
        PhotoViewPreviewView(
            photos: PhotoViewPreviewFactory.portraitPhotos,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 PhotoViewInitialState SquarePhoto",
    ) {
        PhotoViewPreviewView(
            photos: PhotoViewPreviewFactory.squarePhotos,
        )
        .previewable(
            container: ModulePreviewFactory.makeContainer(),
        )
    }
#endif
