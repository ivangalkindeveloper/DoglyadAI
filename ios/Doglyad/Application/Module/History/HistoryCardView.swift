import DoglyadUI
import SwiftUI

struct HistoryCardView: DViewProtocol {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject var theme: DTheme

    let report: USExaminationReport
    let onTap: () -> Void

    private var examinationData: USExaminationData {
        report.examinationData
    }

    var body: some View {
        DButtonCard(
            action: onTap,
        ) {
            HStack(
                alignment: .top,
                spacing: .zero,
            ) {
                if !examinationData.photos.isEmpty {
                    ZStack {
                        ForEach(
                            Array(
                                examinationData.photos.enumerated(),
                            ),
                            id: \.element.id,
                        ) { index, photo in
                            DPhotoCard(
                                image: photo.thumbnail,
                            )
                            .overlay {
                                DCardBackground(
                                    cornerRadius: size.adaptiveCornerRadius / 4,
                                    borderColor: color.grayscaleBackground,
                                    lineWidth: 0.5,
                                )
                            }
                            .offset(
                                x: Double.random(
                                    in: -4 ... 4,
                                ),
                                y: Double.random(
                                    in: -4 ... 4,
                                ),
                            )
                            .rotationEffect(
                                .degrees(
                                    Double.random(
                                        in: -8 ... 8,
                                    ),
                                ),
                            )
                            .zIndex(
                                Double(
                                    index,
                                ),
                            )
                        }
                    }
                    .padding(
                        .trailing,
                        size.s20,
                    )
                }

                VStack(
                    alignment: .leading,
                    spacing: .zero,
                ) {
                    HStack(
                        alignment: .top,
                        spacing: .zero,
                    ) {
                        DText(
                            examinationData.patientName,
                        )
                        .dStyle(
                            font: typography.linkSmall,
                        )
                        .padding(
                            .trailing,
                            size.s8,
                        )

                        Spacer(
                            minLength: .zero,
                        )

                        DText(
                            report.date.localizedTime(),
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleLabel,
                        )
                        .fixedSize()
                    }

                    DText(
                        LocalizedStringResource.forExaminationTypeById(
                            types: container.usExaminationTypesById,
                            id: examinationData.usExaminationTypeId,
                        ),
                    )
                    .dStyle(
                        font: typography.linkSmall,
                        color: color.grayscalePlacehold,
                    )

                    DText(
                        examinationData.examinationDescription,
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleLabel,
                    )
                    .lineLimit(
                        2,
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading,
                )
            }
        }
        .background(
            color.grayscaleBackground,
        )
        .cornerRadius(
            size.s16,
        )
    }
}
