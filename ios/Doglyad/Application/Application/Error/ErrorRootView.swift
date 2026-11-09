import DoglyadUI
import SwiftUI

struct ErrorRootView: DViewProtocol {
    @EnvironmentObject private var applicationViewModel: ApplicationRootViewModel
    @EnvironmentObject var theme: DTheme
    @StateObject private var viewModel: ErrorRootViewModel

    init(
        error: Error,
        analytics: AnalyticsManager?,
    ) {
        _viewModel = StateObject(
            wrappedValue: ErrorRootViewModel(
                error: error,
                analytics: analytics,
            ),
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case _ as ErrorRootNewVersionState:
                NewVersionView(
                    onTapUpdate: viewModel.onTapNewVersionUpdate,
                )
            case _ as ErrorRootOfflineErrorState:
                ErrorView(
                    title: .errorNoInternetConnectionTitle,
                    buttonTitle: .buttonUpdate,
                    action: {
                        viewModel.onTapRetry(
                            onRetryInitialization: applicationViewModel.retryInitialization,
                        )
                    },
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
            case let state as ErrorRootServiceUnavailableErrorState:
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

                        DTextButton(
                            action: viewModel.onTapServiceUnavailableEmail,
                        ) {
                            DText(
                                state.email,
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
            case _ as ErrorRootUnknownErrorState:
                ErrorView(
                    title: .errorUnknownTitle,
                    buttonTitle: .buttonUpdate,
                    action: {
                        viewModel.onTapRetry(
                            onRetryInitialization: applicationViewModel.retryInitialization,
                        )
                    },
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
            default: EmptyView()
            }
        }
        .onAppear(
            perform: viewModel.onAppear,
        )
    }
}
