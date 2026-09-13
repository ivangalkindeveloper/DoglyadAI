import DoglyadUI
import SwiftUI

struct ScanPhotoListView: DView {
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ScanViewModel

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
                        .padding(.horizontal, size.s16)
                    }
                    .padding(.bottom, size.s8)

                    DText(.scanMaxPhotoDescription(count: viewModel.photoMaxCount))
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscalePlacehold,
                            alignment: .center
                        )
                        .padding(.horizontal, size.s16)
                }
                .padding(.bottom, size.s8)
                .transition(.opacity)
            }
        }
        .animation(
            theme.animation,
            value: viewModel.photos
        )
    }
}
