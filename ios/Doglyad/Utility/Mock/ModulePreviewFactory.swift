#if DEBUG
    import Foundation
    import UIKit

    @MainActor
    enum ModulePreviewFactory {
        static let development = DevelopmentPreviewFactory.make()
        static let examinationType = development.examinationTypes.flatMap(
            \.examinationTypes,
        ).first {
            $0.id == "thyroidGland"
        }!
        static let neuralModel = development.neuralModels.first {
            $0.id == "google/medgemma-4b-it"
        }!
        static let readyMadeTemplates = development.readyMadeTemplates
        static let readyMadeTemplate = readyMadeTemplates.first {
            $0.examinationType == examinationType.id
        }!
        static let template = USExaminationTemplate(
            usExaminationType: examinationType,
            name: readyMadeTemplate.title,
            content: readyMadeTemplate.content,
        )
        static let templates = readyMadeTemplates.map { template in
            USExaminationTemplate(
                usExaminationType: development.examinationTypes.flatMap(
                    \.examinationTypes,
                ).first {
                    $0.id == template.examinationType
                }!,
                name: template.title,
                content: template.content,
            )
        }
        static let report = USExaminationReportPreviewFactory.makeReport(
            date: Date(
                timeIntervalSince1970: 1793707200,
            ),
            isPhotosIncluded: true,
        )
        static let photos = report.examinationData.photos
        static let cameraPhotos = (0 ..< 6).map { _ in
            USExaminationScanPhoto(
                image: photos[
                    0,
                ].image,
                thumbnail: photos[
                    0,
                ].thumbnail,
            )
        }
        static let photoRemarks = photos.map { photo in
            USExaminationPhotoRemarks(
                photoId: photo.id,
                points: [
                    USExaminationPhotoRemarkPoint(
                        x: 0.46,
                        y: 0.42,
                        title: "Проверьте контур",
                        description: "Учебное замечание к синтетическому снимку. Уточните границу области измерения.",
                    ),
                    USExaminationPhotoRemarkPoint(
                        x: 0.65,
                        y: 0.61,
                        title: "Область измерения",
                        description: "Учебная отметка модели. Снимок не предназначен для диагностики.",
                    ),
                ],
            )
        }
        static let subscription = SubscriptionManagePreviewFactory.makeStatus(
            source: .robokassa,
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
            isPatientPreparedForExamination: true,
        )
        static let paywallPlans = development.products.products.map { product in
            SubscriptionPlan(
                id: product.id,
                source: .robokassa,
                type: product.entitlement,
                period: product.period,
                title: product.title,
                price: product.formattedPrice(
                    product.price.amountMinor.formattedCurrencyFromMinorUnits(
                        code: product.price.currencyIso2Code,
                        locale: Locale(
                            identifier: "ru",
                        ),
                    ),
                ),
            )
        }
        static let paywallPlan = paywallPlans.first {
            $0.type == .pro && $0.period == .monthly
        }!
        static let paywallContent = PaywallSuccessState(
            tiers: development.products.tiers,
            plans: paywallPlans,
            selectedType: .pro,
            selectedPlanID: paywallPlan.id,
        )

        static func makeContainer() -> DependencyContainer {
            DependencyContainer.makePreviewable(
                l10n: L10NPreviewFactory.make(),
            )
        }
    }
#endif
