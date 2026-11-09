#if DEBUG && DOGLYAD_REGRESSION
    import Foundation

    @MainActor
    enum RegressionFixtures {
        static func prepareSpeechStorage() throws {
            guard Bundle.main.bundleIdentifier == "com.medical.doglyad.local",
                  UserDefaults.standard.bool(
                      forKey: "regressionSeedSpeechModel",
                  )
            else {
                return
            }
            // Tiny filesystem fixtures exercise storage deletion; no model inference is attempted.
            let directory = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
            )[
                0,
            ]
            .appendingPathComponent(
                "WhisperKit/RegressionModel",
                isDirectory: true,
            )
            for name in ["AudioEncoder", "TextDecoder", "MelSpectrogram"] {
                try FileManager.default.createDirectory(
                    at: directory.appendingPathComponent(
                        name + ".mlmodelc",
                    ),
                    withIntermediateDirectories: true,
                )
            }
            try Data(
                "{}".utf8,
            ).write(
                to: directory.deletingLastPathComponent().appendingPathComponent(
                    "tokenizer.json",
                ),
            )
            UserDefaults.standard.set(
                directory.path,
                forKey: "DoglyadSpeech.whisperTurboModelFolder",
            )
        }

        static func prepareHistory(
            repository: any UltrasoundReportRepositoryProtocol,
        ) async throws {
            guard Bundle.main.bundleIdentifier == "com.medical.doglyad.local",
                  UserDefaults.standard.string(
                      forKey: "regressionSeed",
                  ) == "history41"
            else {
                return
            }
            // Only the dedicated regression simulator launches with this flag.
            try await repository.clearAllReports()
            let calendar = Calendar.current
            let today = calendar.startOfDay(
                for: Date(),
            )
            for index in 1 ... 41 {
                let day: Date = if index >= 28 {
                    today
                } else if index >= 14 {
                    calendar.date(
                        byAdding: .day,
                        value: -1,
                        to: today,
                    )!
                } else {
                    calendar.date(
                        from: DateComponents(
                            year: 2020,
                            month: 1,
                            day: 2,
                        ),
                    )!
                }
                let date = day.addingTimeInterval(
                    Double(
                        3600 + index,
                    ),
                )
                let number = String(
                    format: "%03d",
                    index,
                )
                let sample = USExaminationReportPreviewFactory.makeReport(
                    date: date,
                    patientName: "History " + number,
                )
                let values = sample.examinationData
                let report = USExaminationReport(
                    id: UUID(
                        uuidString: "00000000-0000-4000-8000-" + String(
                            format: "%012d",
                            index,
                        ),
                    )!,
                    date: date,
                    settingsAI: sample.settingsAI,
                    examinationData: USExaminationData(
                        usExaminationTypeId: values.usExaminationTypeId,
                        photos: [],
                        examinationNumber: "HISTORY-" + number,
                        patientName: values.patientName,
                        patientGender: values.patientGender,
                        patientDateOfBirth: values.patientDateOfBirth,
                        isPatientConsent: true,
                        patientHeight: values.patientHeight,
                        patientWeight: values.patientWeight,
                        patientComplaints: values.patientComplaints,
                        examinationDescription: values.examinationDescription,
                    ),
                    actualModelReport: sample.actualModelReport,
                    previousModelReports: [],
                )
                try await repository.setReport(
                    report: report,
                )
            }
        }
    }
#endif
