import DoglyadUI
import SwiftUI

struct ErrorRootView: DView {
    @EnvironmentObject private var applicationViewModel: ApplicationViewModel
    @EnvironmentObject var theme: DTheme

    let error: Error
    @StateObject private var viewModel: ErrorRootViewModel

    init(
        error: Error,
        analytics: AnalyticsManager?
    ) {
        self.error = error
        _viewModel = StateObject(
            wrappedValue: ErrorRootViewModel(
                error: error,
                analytics: analytics
            )
        )
    }

    var body: some View {
        let error = error as? InitializationError
        Group {
            switch error {
            case .newVersion:
                NewVersionView(
                    onTapUpdate: viewModel.onTapNewVersionUpdate
                )
            case .noInternetConnection:
                ErrorView(
                    title: .errorNoInternetConnectionTitle,
                    buttonTitle: .buttonUpdate,
                    action: retryInitialization
                ) {
                    DText(.errorNoInternetConnectionDescription)
                }
            case let .serviceUnavailable(email):
                ErrorView(
                    title: .serviceUnavailableTitle
                ) {
                    VStack(
                        spacing: size.s8
                    ) {
                        DText(.serviceUnavailableDescription)

                        Button(
                            action: viewModel.onTapServiceUnavailableEmail
                        ) {
                            DText(email)
                                .dStyle(
                                    font: typography.linkSmall,
                                    color: color.primaryDefault,
                                    alignment: .center
                                )
                                .padding(.vertical, size.s4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            case .usExaminationTypesEmpty,
                 .usExaminationNeuralModelsEmpty,
                 .examinationNeuralModelPromptEmpty,
                 .some(.common),
                 .none:
                ErrorView(
                    title: .errorUnknownTitle,
                    buttonTitle: .buttonUpdate,
                    action: retryInitialization
                ) {
                    DText(.errorUnknownDescription)
                }
            }
        }
        .onAppear(perform: viewModel.onAppear)
    }

    private func retryInitialization() {
        viewModel.onTapRetry()
        applicationViewModel.retryInitialization()
    }
}

#Preview {
    ErrorRootView(
        error: InitializationError.noInternetConnection,
        analytics: AnalyticsManager(isEnabled: false)
    )
    .previewable()
}
