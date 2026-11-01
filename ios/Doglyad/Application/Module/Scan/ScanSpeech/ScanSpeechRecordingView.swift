import DoglyadUI
import SwiftUI

struct ScanSpeechRecordingView: DViewProtocol {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject private var viewModel: ScanSpeechViewModel
    @EnvironmentObject var theme: DTheme

    let toolbarHeight: CGFloat
    let bottomHeight: CGFloat

    var body: some View {
        let description: LocalizedStringResource? = switch viewModel.state {
        case _ as ScanSpeechPreparingRecordingState:
            l10n[
                .scanSpeechProcessPreparingDescription,
            ]
        case _ as ScanSpeechTranscribingState:
            l10n[
                .scanSpeechProcessTranscribingDescription,
            ]
        default: nil
        }

        VStack(
            spacing: .zero,
        ) {
            Spacer()

            ScanSpeechRecordingMeterView()

            if let description {
                DText(
                    description,
                ).dStyle(
                    font: typography.textSmall,
                    color: color.grayscaleBackgroundWeak,
                    alignment: .center,
                )
                .padding(
                    .horizontal,
                    size.s16,
                ).padding(
                    .bottom,
                    size.s8,
                ).transition(
                    .opacity,
                )

            } else {
                Group {
                    DText(
                        l10n[
                            .scanSpeechProcessDescription,
                        ],
                    ).dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleBackgroundWeak,
                        alignment: .center,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    ).padding(
                        .bottom,
                        size.s8,
                    )

                    DText(
                        l10n[
                            .scanSpeechProcessSpeechDescription,
                        ],
                    ).dStyle(
                        font: typography.textSmall,
                        color: color.grayscaleBackgroundWeak,
                        alignment: .center,
                    )
                    .padding(
                        .horizontal,
                        size.s16,
                    )
                }.transition(
                    .opacity,
                )
            }

            Spacer()
        }.padding(
            size.s16,
        )
        .padding(
            .top,
            toolbarHeight,
        )
        .padding(
            .bottom,
            bottomHeight,
        )
    }
}
