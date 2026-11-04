#if DEBUG
    import Foundation
    import UIKit

    @MainActor
    enum ModulePreviewFactory {
        static let examinationType = USExaminationType(
            id: "thyroidGland",
            title: "Щитовидная железа",
            contextualStrings: [],
        )
        static let neuralModel = USExaminationNeuralModel(
            id: "google/medgemma-4b-it",
            title: "MedGemma",
            entitlement: .base,
            accessibility: .available,
            contextLength: 8192,
            description: "Анализ ультразвукового исследования",
        )
        static let template = USExaminationTemplate(
            usExaminationType: examinationType,
            name: "Щитовидная железа — норма",
            content: USExaminationReportPreviewFactory.description,
        )
        static let readyMadeTemplate = USExaminationReadyMadeTemplate(
            id: "thyroid-normal",
            examinationType: examinationType.id,
            title: template.name,
            content: template.content,
        )
        static let report = USExaminationReportPreviewFactory.makeReport(
            date: Date(
                timeIntervalSince1970: 1793707200,
            ),
            isPhotosIncluded: true,
        )
        static let photos = report.examinationData.photos
        static let subscription = ManageSubscriptionPreviewFactory.makeStatus(
            source: .yookassa,
        )
        static let draft = USExaminationDraftForm(
            examinationNumber: "PREVIEW-001",
            patientName: "Тестовый пациент",
            patientGender: .female,
            patientDateOfBirth: Date(
                timeIntervalSince1970: 631152000,
            ),
            patientHeightCM: "168",
            patientWeightKG: "62",
            patientComplaints: "Нет",
            examinationDescription: USExaminationReportPreviewFactory.description,
        )
        static let paywallPlan = SubscriptionPlan(
            id: "pro_monthly",
            source: .yookassa,
            type: .pro,
            period: .monthly,
            title: "Pro — месяц",
            price: "990 ₽ в месяц",
        )
        static let paywallContent = PaywallDefaultState(
            tiers: [SubscriptionTier(
                id: .pro,
                title: "Pro",
                features: ["20 протоколов в день", "Заполнение голосом", "Отправка на почту"],
            )],
            plans: [paywallPlan],
            selectedType: .pro,
            selectedPlanID: paywallPlan.id,
        )
        static let documentURL = URL(
            string: "data:text/html;base64," + Data(
                "<html lang='ru'><meta name='viewport' content='width=device-width'><body><h1>Документ</h1><p>Пример документа для просмотра интерфейса.</p></body></html>".utf8,
            ).base64EncodedString(),
        )!

        static func makeContainer() -> DependencyContainer {
            DependencyContainer.makePreviewable(
                l10n: L10NPreviewFactory.make(),
                usExaminationTypesById: [examinationType.id: examinationType],
                usExaminationTypeGroups: [USExaminationTypeGroup(
                    id: "general",
                    title: "Общие исследования",
                    examinationTypes: [examinationType],
                )],
                usExaminationNeuralModels: [neuralModel],
            )
        }
    }
#endif
