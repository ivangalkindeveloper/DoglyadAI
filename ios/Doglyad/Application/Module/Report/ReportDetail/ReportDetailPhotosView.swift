import DoglyadUI
import SwiftUI

struct ReportDetailPhotosView: DView {
    @EnvironmentObject var theme: DTheme

    @EnvironmentObject private var viewModel: ReportDetailViewModel

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
                    PhotoCardView(
                        image: photo.thumbnail,
                        configuration: viewModel.photoCardConfiguration(
                            for: photo.id,
                        ),
                        onTap: { viewModel.onTapPhoto(
                            photo,
                        ) },
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
            size.s16,
        )
    }
}
