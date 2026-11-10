#if DEBUG
    import DoglyadCamera
    import Foundation
    import UIKit

    @MainActor
    enum USExaminationReportPreviewFactory {
        static let description = """
        Щитовидная железа расположена обычно. Контуры ровные, чёткие.
        Правая доля: 45 × 16 × 17 мм. Левая доля: 43 × 15 × 16 мм. Перешеек: 3 мм.
        Эхогенность обычная, структура однородная. Очаговые образования не выявлены.
        """
        static let conclusion = "Ультразвуковых признаков структурных изменений щитовидной железы не выявлено."

        static func makeReport(
            date: Date = Date(),
            patientName: String = "Тестовый пациент",
            isPhotosIncluded: Bool = false,
            modelReport: USExaminationModelReport? = nil,
        ) -> USExaminationReport {
            USExaminationReport(
                date: date,
                settingsAI: SettingsAI(
                    selectedNeuralModelId: "google/medgemma-4b-it",
                    isMarkdown: true,
                    temperature: nil,
                    maxTokens: nil,
                ),
                examinationData: USExaminationData(
                    usExaminationTypeId: "thyroidGland",
                    photos: isPhotosIncluded ? [
                        USExaminationScanPhoto(
                            image: SimulatorCameraImageFactory.makeImage(
                                captureNumber: 1,
                            ),
                        ),
                    ] : [],
                    examinationNumber: "PREVIEW-001",
                    patientName: patientName,
                    patientGender: .female,
                    patientDateOfBirth: Date(
                        timeIntervalSince1970: 631152000,
                    ),
                    patientHeight: 168,
                    patientWeight: 62,
                    patientComplaints: nil,
                    examinationDescription: description,
                    isPatientPreparedForExamination: true,
                    isPatientConsent: true,
                ),
                actualModelReport: modelReport ?? USExaminationModelReport(
                    date: date,
                    modelId: "google/medgemma-4b-it",
                    description: description,
                    conclusion: conclusion,
                    recommendations: nil,
                ),
                previousModelReports: [],
            )
        }
    }
#endif
