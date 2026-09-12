import DoglyadUI
import SwiftUI

struct ScanSheetHeaderView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @EnvironmentObject private var viewModel: ScanViewModel
    private var isBottom: Bool { viewModel.sheetController.isBottom }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: .zero
        ) {
            if !viewModel.photos.isEmpty {
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
                        .padding([.horizontal], size.s2)
                    }
                    .padding([.horizontal], size.s14)
                }
                .padding(.bottom, size.s8)
                .transition(.opacity)

                DText(.scanMaxPhotoDescription(count: viewModel.photoMaxCount))
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscalePlacehold
                    )
                    .padding(.horizontal, size.s24)
                    .padding(.bottom, isBottom ? size.s32 : size.s8)
            }
        }
        .animation(
            theme.animation,
            value: viewModel.photos
        )
    }
}
