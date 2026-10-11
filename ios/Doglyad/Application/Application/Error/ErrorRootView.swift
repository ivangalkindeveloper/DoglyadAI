import DoglyadUI
import SwiftUI

struct ErrorRootView: DView {
    @EnvironmentObject private var applicationViewModel: ApplicationRootViewModel
    @EnvironmentObject var theme: DTheme

    let error: Error
    @StateObject private var viewModel: ErrorRootViewModel

    init(
        error: Error,
        analytics: AnalyticsManager?,
    ) {
        self.error = error
        _viewModel = StateObject(
            wrappedValue: ErrorRootViewModel(
                error: error,
                analytics: analytics,
            ),
        )
    }

    var body: some View {
        let error = error as? InitializationError
        Group {
            switch error {
            case .newVersion:
                NewVersionView(
                    onTapUpdate: viewModel.onTapNewVersionUpdate,
                )
            case .noInternetConnection:
                ErrorView(
                    title: .errorNoInternetConnectionTitle,
                    buttonTitle: .buttonUpdate,
                    action: { viewModel.onTapRetry(
                        onRetryInitialization: applicationViewModel.retryInitialization,
                    ) },
                ) {
                    DText(
                        .errorNoInternetConnectionDescription,
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscalePlacehold,
                        alignment: .center,
                    )
                }
            case let .serviceUnavailable(
                email,
            ):
                ErrorView(
                    title: .serviceUnavailableTitle,
                ) {
                    VStack(
                        spacing: size.s8,
                    ) {
                        DText(
                            .serviceUnavailableDescription,
                        )
                        .dStyle(
                            font: typography.textSmall,
                            color: color.grayscalePlacehold,
                            alignment: .center,
                        )

                        DButtonCard(
                            isPlain: true,
                            action: viewModel.onTapServiceUnavailableEmail,
                        ) {
                            DText(
                                email,
                            )
                            .dStyle(
                                font: typography.linkSmall,
                                color: color.primaryDefault,
                                alignment: .center,
                            )
                            .padding(
                                .vertical,
                                size.s4,
                            )
                        }
                        .buttonStyle(
                            .plain,
                        )
                    }
                }
            case .usExaminationTypesEmpty,
                 .usExaminationNeuralModelsEmpty,
                 .some(
                     .common,
                 ),
                 .none:
                ErrorView(
                    title: .errorUnknownTitle,
                    buttonTitle: .buttonUpdate,
                    action: { viewModel.onTapRetry(
                        onRetryInitialization: applicationViewModel.retryInitialization,
                    ) },
                ) {
                    DText(
                        .errorUnknownDescription,
                    )
                    .dStyle(
                        font: typography.textSmall,
                        color: color.grayscalePlacehold,
                        alignment: .center,
                    )
                }
            }
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}

#Preview {
    ErrorRootView(
        error: InitializationError.noInternetConnection,
        analytics: AnalyticsManager(
            isEnabled: false,
        ),
    )
    .previewable()
}
