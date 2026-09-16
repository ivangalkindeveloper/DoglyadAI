import DoglyadUI
import SwiftUI

struct ScanCameraPhotoListView: DView {
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanCameraViewModel

    var body: some View {
        Group {
            if !viewModel.photos.isEmpty {
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
                            ForEach(viewModel.photos) { photo in
                                PhotoCardView(
                                    image: photo.thumbnail,
                                    actionDelete: {
                                        viewModel.onTapDeletePhoto(photo: photo)
                                    }
                                )
                                .transition(.opacity)
                            }
                            .padding(.horizontal, size.s2)
                        }
                        .padding(.horizontal, size.s8)
                    }
                    .padding(.bottom, size.s8)

                    DText(.scanMaxPhotoDescription(count: viewModel.photoMaxCount))
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleLine,
                            alignment: .center
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, size.s16)
                }
                .transition(.opacity)
            }
        }
        .animation(
            theme.animation,
            value: viewModel.photos
        )
    }
}
