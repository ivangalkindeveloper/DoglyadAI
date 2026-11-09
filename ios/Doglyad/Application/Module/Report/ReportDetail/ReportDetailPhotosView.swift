import DoglyadUI
import SwiftUI

struct ReportDetailPhotosView: DViewProtocol {
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ReportDetailViewModel
    var isDisabled: Bool = false

    var body: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false,
        ) {
            HStack(
                alignment: .bottom,
                spacing: .zero,
            ) {
                ForEach(
                    viewModel.report.examinationData.photos,
                ) { photo in
                    DPhotoCard(
                        image: photo.thumbnail,
                        configuration: viewModel.photoCardConfiguration(
                            for: photo.id,
                        ),
                        onTap: {
                            viewModel.onTapPhoto(
                                photo,
                            )
                        },
                        isDisabled: isDisabled,
                        accessibilityIdentifier: "reportDetail.photo.\(photo.id)",
                    )
                }
            }
            .padding(
                .horizontal,
                size.s16,
            )
        }
        .padding(
            .bottom,
            viewModel.report.examinationData.photos.isEmpty ? .zero : size.s16,
        )
    }
}
