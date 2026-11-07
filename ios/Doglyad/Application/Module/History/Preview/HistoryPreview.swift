#if DEBUG
    import DoglyadCamera
    import DoglyadUI
    import Router
    import SwiftUI

    #Preview(
        "01 Загрузка истории",
    ) {
        HistoryPreviewView(
            scenario: .loading,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "02 Ошибка загрузки истории",
    ) {
        HistoryPreviewView(
            scenario: .failed,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "03 Пустая история",
    ) {
        HistoryPreviewView(
            scenario: .empty,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "04 Одно исследование",
    ) {
        HistoryPreviewView(
            scenario: .singleReport,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "05 История · группы дат и разные протоколы",
    ) {
        HistoryPreviewView(
            scenario: .groupedReports,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "06 Загрузка следующей страницы",
    ) {
        HistoryPreviewView(
            scenario: .loadingNextPage,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "07 Ошибка следующей страницы",
    ) {
        HistoryPreviewView(
            scenario: .nextPageFailed,
        )
        .previewable(
            container: HistoryPreviewFactory.makeContainer(),
        )
    }

    #Preview(
        "08 Карточка исследования",
    ) {
        HistoryCardView(
            report: USExaminationReport(
                date: Date(),
                settingsAI: SettingsAI(
                    selectedNeuralModelId: "google/medgemma-1.5-4b-it",
                    isMarkdown: false,
                    temperature: nil,
                    maxTokens: nil,
                ),
                examinationData: USExaminationData(
                    usExaminationTypeId: "thyroidGland",
                    photos: [
                        USExaminationScanPhoto(
                            image: SimulatorCameraImageFactory.makeImage(
                                captureNumber: 1,
                            ),
                        ),
                        USExaminationScanPhoto(
                            image: SimulatorCameraImageFactory.makeImage(
                                captureNumber: 1,
                            ),
                        ),
                        USExaminationScanPhoto(
                            image: SimulatorCameraImageFactory.makeImage(
                                captureNumber: 1,
                            ),
                        ),
                    ],
                    examinationNumber: "Examination#0",
                    patientName: "Patient#0",
                    patientGender: .male,
                    patientDateOfBirth: Date(),
                    patientHeight: 180.0,
                    patientWeight: 80.0,
                    patientComplaints: """
                    The patient reports an intermittent feeling of pressure in the neck.
                    They report mild discomfort while swallowing during the last two weeks.
                    They also mention general weakness and increased fatigue.
                    No similar symptoms were previously observed.
                    The patient reports no pain.
                    """,
                    examinationDescription: """
                    A thyroid ultrasound was performed in standard longitudinal and transverse planes.
                    The lobes are symmetrical, with smooth and well-defined contours.
                    The parenchyma is homogeneous with moderate echogenicity.
                    No focal lesions were identified.
                    The regional lymph nodes are unremarkable.
                    """,
                ),
                actualModelReport: USExaminationModelReport(
                    date: Date(),
                    modelId: "google/medgemma-1.5-4b-it",
                    description: """
                    No signs of thyroid nodules or cystic changes were identified.
                    The organ dimensions are within the normal range for age.
                    The parenchymal echotexture is preserved, with no pathological inclusions.
                    No evidence of an inflammatory process was found.
                    The ultrasound findings are within normal limits.
                    """,
                    conclusion: "The ultrasound findings are within normal limits.",
                    recommendations: "Routine follow-up when clinically indicated.",
                ),
                previousModelReports: [
                    USExaminationModelReport(
                        date: Date(),
                        modelId: "google/medgemma-1.5-4b-it",
                        description: """
                        No signs of thyroid nodules or cystic changes were identified.
                        The organ dimensions are within the normal range for age.
                        The parenchymal echotexture is preserved, with no pathological inclusions.
                        No evidence of an inflammatory process was found.
                        The ultrasound findings are within normal limits.
                        """,
                        conclusion: "The ultrasound findings are within normal limits.",
                        recommendations: "Routine follow-up when clinically indicated.",
                    ),
                    USExaminationModelReport(
                        date: Date(),
                        modelId: "google/medgemma-1.5-4b-it",
                        description: """
                        The thyroid is in its normal position and its structure is preserved.
                        Both lobes are within the normal size range for age, with no abnormalities.
                        Parenchymal echogenicity is uniform, without pathological decreases or increases.
                        No focal lesions, nodules, cysts, or calcifications were detected.
                        The gland contours are smooth and well defined; the capsule is not thickened.
                        Color Doppler shows no increased blood flow; values are physiological.
                        Regional lymph nodes show no enlargement or structural changes.
                        No signs of inflammation or autoimmune involvement were observed.
                        The findings correspond to a normal thyroid ultrasound appearance.
                        Routine follow-up ultrasound is recommended when clinically indicated.
                        """,
                        conclusion: "The findings correspond to a normal thyroid ultrasound appearance.",
                        recommendations: "Routine follow-up when clinically indicated.",
                    ),
                ],
            ),
            onTap: {},
        )
        .padding()
        .dThemeWrapper()
    }
#endif
