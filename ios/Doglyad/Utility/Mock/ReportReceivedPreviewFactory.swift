#if DEBUG
    import Combine
    import DoglyadUI
    import Foundation

    @MainActor
    enum ReportReceivedPreviewFactory {
        enum Scenario: Hashable {
            case waitingForFirstToken, firstToken, streamingDescription, streamingConclusion
            case completed, completedWithRemarks, fromReportDetail
            case withoutEmail, emailOffered, emailUnavailable, sendingEmail, deliveryFailed
            case interruptedWithoutText, interrupted, failedWithoutText, failed, cancelled
        }

        static func makeViewModel(
            scenario: Scenario,
            container: DependencyContainer,
            messager: DMessager,
            router: DRouter,
        ) -> ReportReceivedViewModel {
            let report = makeReport(
                scenario: scenario,
            )
            let availability: SubscriptionFeatureAvailability = switch scenario {
            case .emailOffered: .offered
            case .emailUnavailable: .unavailable
            default: .available
            }
            let status = SubscriptionStatus(
                planId: scenario == .emailOffered ? "base_monthly" : "pro_monthly",
                type: scenario == .emailOffered ? .base : .pro,
                entitlement: SubscriptionEntitlement(
                    requestCountPerDay: 20,
                    formCompletionViaMicrophone: .available,
                    sendingReportByEmail: availability,
                    settingsAI: .available,
                ),
                availableCountPerDay: 17,
            )
            let model = ReportReceivedViewModel(
                container: container,
                messager: messager,
                router: router,
                arguments: ReportReceivedArguments(
                    isReportNavigationAvailable: scenario != .fromReportDetail,
                    report: report,
                ),
                getSubscriptionStatus: {
                    status
                },
                observeSubscriptionStatus: { _ in
                    AnyCancellable {}
                },
                onSubscriptionStatusUpdated: { _ in },
                getSettingsAI: {
                    container.initialSettingsAI
                },
                onRefreshSubscriptionStatus: {},
                getUserEmail: {
                    scenario == .withoutEmail ? nil : "doctor.with.long.address@example.com"
                },
                currentReport: {
                    $0
                },
                observeReports: { _ in
                    AnyCancellable {}
                },
                retryGeneration: {
                    $0
                },
            )
            // Initialize the inert observers before setting the fixed delivery state.
            model.onAppear()
            switch scenario {
            case .sendingEmail:
                model.emit(
                    ReportReceivedLoadingState(
                        report: report,
                    ),
                    animation: nil,
                )
            case .deliveryFailed:
                model.emit(
                    ReportReceivedDeliveryFailedState(
                        report: report,
                        error: URLError(
                            .notConnectedToInternet,
                        ),
                    ),
                    animation: nil,
                )
            default: break
            }
            return model
        }

        private static func makeReport(
            scenario: Scenario,
        ) -> USExaminationReport {
            let status: USReportGenerationStatus
            let description: String
            let conclusion: String
            var recommendations: String?
            var descriptionRemarks: String?
            switch scenario {
            case .waitingForFirstToken:
                status = .generating
                description = ""
                conclusion = ""
            case .firstToken:
                status = .generating
                description = "Щ"
                conclusion = ""
            case .streamingDescription:
                status = .generating
                description = "Щитовидная железа расположена обычно. Контуры ровные, чёткие. Правая доля: 45 × 16"
                conclusion = ""
            case .streamingConclusion:
                status = .generating
                description = USExaminationReportPreviewFactory.description
                conclusion = "Ультразвуковых признаков структурных"
            case .interruptedWithoutText, .failedWithoutText:
                status = scenario == .interruptedWithoutText ? .interrupted : .failed
                description = ""
                conclusion = ""
            case .interrupted, .failed, .cancelled:
                status = switch scenario {
                case .interrupted: .interrupted
                case .cancelled: .cancelled
                default: .failed
                }
                description = Array(
                    repeating: USExaminationReportPreviewFactory.description,
                    count: 4,
                ).joined(
                    separator: "\n\n",
                )
                conclusion = "Ультразвуковых признаков"
            case .completedWithRemarks:
                status = .completed
                description = USExaminationReportPreviewFactory.description
                conclusion = USExaminationReportPreviewFactory.conclusion
                recommendations = "Сопоставить результат с жалобами и данными предыдущих исследований."
                descriptionRemarks = "В исходном описании отсутствуют сведения о регионарных лимфатических узлах."
            default:
                status = .completed
                description = USExaminationReportPreviewFactory.description
                conclusion = USExaminationReportPreviewFactory.conclusion
            }
            return USExaminationReportPreviewFactory.makeReport(
                modelReport: USExaminationModelReport(
                    date: Date(),
                    modelId: "google/medgemma-4b-it",
                    description: description,
                    conclusion: conclusion,
                    recommendations: recommendations,
                    descriptionRemarks: descriptionRemarks,
                    generation: USReportGeneration(
                        status: status,
                    ),
                ),
            )
        }
    }
#endif
