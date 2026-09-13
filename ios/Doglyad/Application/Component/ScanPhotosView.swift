import DoglyadUI
import SwiftUI

struct ScanPhotosView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    let photos: [USExaminationScanPhoto]
    let photoMaxCount: Int
    let onTapDelete: (USExaminationScanPhoto) -> Void

    var body: some View {
        if !photos.isEmpty {
            VStack(
                alignment: .leading,
                spacing: .zero
            ) {
                ScrollView(
                    .horizontal,
                    showsIndicators: false
                ) {
                    HStack(
                        spacing: .zero
                    ) {
                        ForEach(photos) { photo in
                            PhotoCardView(
                                image: photo.thumbnail,
                                actionDelete: {
                                    onTapDelete(photo)
                                }
                            )
                            .transition(.opacity)
                        }
                        .padding(.horizontal, size.s2)
                    }
                    .padding(.horizontal, size.s14)
                }
                .padding(.bottom, size.s8)

                DText(.scanMaxPhotoDescription(count: photoMaxCount))
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscalePlacehold,
                        alignment: .center
                    )
                    .padding(.horizontal, size.s24)
            }
            .padding(.bottom, size.s8)
            .transition(.opacity)
            .animation(
                theme.animation,
                value: photos
            )
        }
    }
}
