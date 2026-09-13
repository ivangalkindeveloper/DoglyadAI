import DoglyadUI
import SwiftUI

struct ReportDetailPhotosView: View {
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    @EnvironmentObject private var viewModel: ReportDetailViewModel

    var body: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            HStack(
                spacing: .zero
            ) {
                ForEach(viewModel.report.examinationData.photos) { photo in
                    PhotoCardView(
                        image: photo.thumbnail
                    )
                }
                .padding([.horizontal], size.s2)
            }
            .padding([.horizontal], size.s14)
        }
        .padding(.bottom, size.s16)
    }
}
