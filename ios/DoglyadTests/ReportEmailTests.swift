@testable import Doglyad
import Foundation
import Testing
import UIKit

struct ReportEmailTests {
    @MainActor
    @Test
    func reportEmailContainsCompressedScanPhotos() throws {
        let sourceImage = UIGraphicsImageRenderer(
            size: CGSize(width: 40, height: 20)
        ).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 20))
        }
        let report = USExaminationReport(
            date: Date(timeIntervalSince1970: 0),
            neuralModelSettings: NeuralModelSettings(
                selectedNeuralModelId: "test",
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "test",
                photos: [USExaminationScanPhoto(image: sourceImage)],
                examinationNumber: "Examination#0",
                patientName: "Patient",
                patientGender: .male,
                patientDateOfBirth: Date(timeIntervalSince1970: 0),
                patientHeight: 180,
                patientWeight: 80,
                patientComplaints: nil,
                examinationDescription: "Description"
            ),
            actualModelReport: USExaminationModelReport(
                date: Date(timeIntervalSince1970: 0),
                modelId: "test",
                description: "Description",
                conclusion: "Conclusion",
                recommendations: nil
            ),
            previousModelReports: []
        )

        let email = report.makeEmail(
            recipientEmail: "doctor@example.com",
            examinationTypesById: [:],
            scanPhotoEncodingOptions: ScanPhotoEncodingOptions(
                resizeMaxDimension: 10,
                compressionQuality: 0.8
            )
        )

        #expect(email.recipientEmail == "doctor@example.com")
        #expect(email.attachments.count == 1)
        #expect(email.attachments[0].fileName == "ultrasound-1.jpg")
        #expect(email.attachments[0].mimeType == "image/jpeg")
        let attachmentImage = try #require(UIImage(data: email.attachments[0].data))
        #expect(attachmentImage.size.width <= 10)
        #expect(attachmentImage.size.height <= 10)

        let payload = try JSONEncoder().encode(email)
        let json = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let attachments = try #require(json["attachments"] as? [[String: Any]])
        let encodedData = try #require(attachments.first?["data"] as? String)
        #expect(Data(base64Encoded: encodedData) == email.attachments[0].data)
    }
}
