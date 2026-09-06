import DoglyadUI
import SwiftUI

struct ErrorRootView: View {
    @EnvironmentObject private var viewModel: ApplicationViewModel
    @EnvironmentObject private var theme: DTheme
    private var color: DColor { theme.color }
    private var size: DSize { theme.size }
    private var typography: DTypography { theme.typography }

    let error: Error
    @StateObject private var analyticsViewModel: ErrorRootViewModel

    init(
        error: Error,
        analytics: AnalyticsManager?
    ) {
        self.error = error
        _analyticsViewModel = StateObject(
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
            case .noInternetConnection:
                ErrorView(
                    title: .errorNoInternetConnectionTitle,
                    buttonTitle: .buttonUpdate,
                    action: retryInitialization
                ) { _ in
                    DText(.errorNoInternetConnectionDescription)
                }
            case .noCameraRequestDenied:
                ErrorView(
                    title: .errorNoCameraPermissionTitle,
                    buttonTitle: .buttonOpenSettings,
                    action: openSettings
                ) { _ in
                    DText(.errorNoCameraPermissionDescription)
                }
            case let .serviceUnavailable(email):
                ErrorView(
                    email: email,
                    title: .serviceUnavailableTitle
                ) { errorViewModel in
                    VStack(
                        spacing: size.s8
                    ) {
                        DText(.serviceUnavailableDescription)

                        Button(
                            action: {
                                analyticsViewModel.onTapServiceUnavailableEmail()
                                errorViewModel.onTapEmail()
                            }
                        ) {
                            DText(errorViewModel.email ?? email)
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
                ) { _ in
                    DText(.errorUnknownDescription)
                }
            }
        }
        .onAppear(perform: analyticsViewModel.onAppear)
    }

    private func retryInitialization() {
        analyticsViewModel.onTapRetry()
        viewModel.retryInitialization()
    }

    private func openSettings() {
        analyticsViewModel.onTapOpenSettings()
        viewModel.openSettings()
    }
}

#Preview {
    ErrorRootView(
        error: InitializationError.noInternetConnection,
        analytics: AnalyticsManager(isEnabled: false)
    )
    .previewable()
}
