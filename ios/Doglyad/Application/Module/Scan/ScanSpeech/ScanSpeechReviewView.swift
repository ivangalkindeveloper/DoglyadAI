import DoglyadUI
import SwiftUI

struct ScanSpeechReviewView: DView {
    @EnvironmentObject private var l10n: L10N
    @EnvironmentObject var theme: DTheme
    @EnvironmentObject private var viewModel: ScanSpeechViewModel

    var body: some View {
        VStack(
            spacing: size.s16,
        ) {
            ScrollView {
                VStack(
                    alignment: .leading,
                    spacing: size.s16,
                ) {
                    if let reviewStatusDescription = viewModel.reviewStatusDescription {
                        DText(
                            reviewStatusDescription,
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscaleHeader,
                        )
                    }

                    DTextField(
                        controller: viewModel.transcriptController,
                        title: l10n[
                            .speechReviewFieldTitle,
                        ],
                        placeholder: l10n[
                            .speechReviewFieldPlaceholder,
                        ],
                        mode: DTextFieldMultiLineMode(
                            lineLimit: 6 ... 14,
                        ),
                    )
                    .disabled(
                        viewModel.isLoading,
                    )
                }
            }
            .scrollDismissesKeyboard(
                .interactively,
            )

            DButton(
                title: l10n[
                    .speechReviewContinueButton,
                ],
                action: viewModel.onTapContinue,
                isLoading: viewModel.isLoading,
                isDisabled: viewModel.isReviewContinueDisabled,
            )
            .dStyle(
                .primaryButton,
            )

            DButton(
                title: l10n[
                    .speechReviewRecordAgainButton,
                ],
                action: viewModel.onTapRecordAgain,
                isDisabled: viewModel.isLoading,
            )
            .dStyle(
                .primaryText,
            )
        }
        .padding(
            size.s16,
        )
    }
}
