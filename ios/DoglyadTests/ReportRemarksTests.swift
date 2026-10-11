import Combine
@testable import Doglyad
import DoglyadDatabase
import Foundation
import Router
import SwiftData
import Testing
import UIKit

@MainActor
@Suite(
    .serialized,
)
struct ReportRemarksTests {
    @Test
    func requestPreservesPhotoIdentityAndNormalizedOrientation() throws {
        let original = UIGraphicsImageRenderer(
            size: CGSize(
                width: 80,
                height: 40,
            ),
        ).image { context in
            UIColor.white.setFill()
            context.fill(
                CGRect(
                    x: 0,
                    y: 0,
                    width: 80,
                    height: 40,
                ),
            )
        }
        let rotated = try UIImage(
            cgImage: #require(
                original.cgImage,
            ),
            scale: 1,
            orientation: .right,
        )
        let photo = USExaminationScanPhoto(
            image: rotated,
        )
        #expect(
            photo.image.imageOrientation == .up,
        )
        let encoder = JSONEncoder()
        encoder.userInfo[
            .scanPhotoEncodingOptions,
        ] = ScanPhotoEncodingOptions(
            resizeMaxDimension: 16,
            compressionQuality: 0.5,
        )
        let encoded = try encoder.encode(
            photo,
        )
        let decoded = try JSONDecoder().decode(
            USExaminationScanPhoto.self,
            from: encoded,
        )
        #expect(
            decoded.id == photo.id,
        )
        #expect(
            max(
                decoded.image.size.width,
                decoded.image.size.height,
            ) <= 16,
        )
        let json = try #require(
            JSONSerialization.jsonObject(
                with: encoded,
            ) as? [String: Any],
        )
        #expect(
            try UUID(
                uuidString: #require(
                    json[
                        "id",
                    ] as? String,
                ),
            ) == photo.id,
        )
    }

    @Test
    func responseDecodesRemarksAndExportsProtocolText() throws {
        let photoId = UUID()
        let json = """
        {"date":0,"modelId":"test","description":"Findings","conclusion":"Conclusion",
         "recommendations":null,"descriptionRemarks":"Description remark",
         "photoRemarks":[{"photoId":"\(photoId)","points":[{"x":0.25,"y":0.75,"title":"Image finding","description":"Image remark"}]}]}
        """
        let report = try JSONDecoder().decode(
            USExaminationModelReport.self,
            from: Data(
                json.utf8,
            ),
        )
        #expect(
            report.descriptionRemarks == "Description remark",
        )
        #expect(
            report.photoRemarks.first?.photoId == photoId,
        )
        #expect(
            report.photoRemarks.first?.points.first?.x == 0.25,
        )
        #expect(
            report.photoRemarks.first?.points.first?.title == "Image finding",
        )
        #expect(
            report.photoRemarks.first?.points.first?.description == "Image remark",
        )
        let text = try report.plainText(
            l10n: VoiceLocalizationTestSupport.l10n(
                code: "en",
            ),
        )
        #expect(
            text.contains(
                "Findings",
            ),
        )
        #expect(
            !text.contains(
                "Description remark",
            ),
        )
        #expect(
            !text.contains(
                "Image remark",
            ),
        )
    }

    @Test
    func reportHistoryPersistsRemarksAndCascadesTheirDeletion() throws {
        let schema = Schema(
            [
                NeuralModelSettingsDB.self,
                USExaminationReportDB.self,
                USExaminationDataDB.self,
                USExaminationScanPhotoDB.self,
                USExaminationModelReportDB.self,
                USExaminationPhotoRemarksDB.self,
                USExaminationPhotoRemarkPointDB.self,
            ],
        )
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(
                isStoredInMemoryOnly: true,
            ),
        )
        let context = ModelContext(
            container,
        )
        let photoId = UUID()
        let point = USExaminationPhotoRemarkPoint(
            x: 0.25,
            y: 0.75,
            title: "Current image finding",
            description: "Current image remark",
        )
        let current = USExaminationModelReport(
            date: Date(),
            modelId: "current",
            description: "Findings",
            conclusion: "Conclusion",
            recommendations: nil,
            descriptionRemarks: "Current description remark",
            photoRemarks: [USExaminationPhotoRemarks(
                photoId: photoId,
                points: [point],
            )],
        )
        let previous = USExaminationModelReport(
            date: Date(),
            modelId: "previous",
            description: "Findings",
            conclusion: "Conclusion",
            recommendations: nil,
            descriptionRemarks: "Previous description remark",
            photoRemarks: [USExaminationPhotoRemarks(
                photoId: photoId,
                points: [
                    USExaminationPhotoRemarkPoint(
                        x: 0.5,
                        y: 0.5,
                        title: "Previous image finding",
                        description: "Previous image remark",
                    ),
                ],
            )],
        )
        let image = UIGraphicsImageRenderer(
            size: CGSize(
                width: 4,
                height: 4,
            ),
        ).image { _ in }
        let report = USExaminationReport(
            date: Date(),
            neuralModelSettings: NeuralModelSettings(
                selectedNeuralModelId: "current",
                isMarkdown: false,
                temperature: nil,
                maxTokens: nil,
            ),
            examinationData: USExaminationData(
                usExaminationTypeId: "test",
                photos: [USExaminationScanPhoto(
                    id: photoId,
                    image: image,
                )],
                examinationNumber: "0",
                patientName: "Patient",
                patientGender: .male,
                patientDateOfBirth: Date(),
                patientHeight: nil,
                patientWeight: nil,
                patientComplaints: nil,
                examinationDescription: "Input description",
            ),
            actualModelReport: current,
            previousModelReports: [previous],
        )
        context.insert(
            report.toDB(),
        )
        try context.save()
        let reopenedContext = ModelContext(
            container,
        )
        let stored = try #require(
            reopenedContext.fetch(
                FetchDescriptor<USExaminationReportDB>(),
            ).first,
        )
        let restored = USExaminationReport.fromDB(
            stored,
        )
        #expect(
            restored.actualModelReport.descriptionRemarks == current.descriptionRemarks,
        )
        #expect(
            restored.actualModelReport.photoRemarks.first?.photoId == photoId,
        )
        #expect(
            restored.actualModelReport.photoRemarks.first?.points.first?.id == point.id,
        )
        #expect(
            restored.actualModelReport.photoRemarks.first?.points.first?.y == point.y,
        )
        #expect(
            restored.actualModelReport.photoRemarks.first?.points.first?.title == point.title,
        )
        #expect(
            restored.actualModelReport.photoRemarks.first?.points.first?.description == point.description,
        )
        #expect(
            restored.previousModelReports.first?.descriptionRemarks == previous.descriptionRemarks,
        )
        #expect(
            restored.previousModelReports.first?.photoRemarks.first?.points.first?.description == "Previous image remark",
        )
        #expect(
            restored.previousModelReports.first?.photoRemarks.first?.points.first?.title == "Previous image finding",
        )
        reopenedContext.delete(
            stored,
        )
        try reopenedContext.save()
        #expect(
            try reopenedContext.fetchCount(
                FetchDescriptor<USExaminationPhotoRemarksDB>(),
            ) == 0,
        )
        #expect(
            try reopenedContext.fetchCount(
                FetchDescriptor<USExaminationPhotoRemarkPointDB>(),
            ) == 0,
        )
    }

    @Test
    func photoViewerRestoresVisibilityAndShowsOnlyCurrentPhotoRemarks() {
        let container = DependencyContainer.previewable
        let settings = container.userSettingsRepository
        let initialIsPhotoRemarks = settings.getIsPhotoRemarks()
        let initialIsDescriptionRemarks = settings.getIsDescriptionRemarks()
        let initialIsRemarksVisible = settings.getIsRemarksVisible()
        defer {
            settings.setIsPhotoRemarks(
                initialIsPhotoRemarks,
            )
            settings.setIsDescriptionRemarks(
                initialIsDescriptionRemarks,
            )
            settings.setIsRemarksVisible(
                initialIsRemarksVisible,
            )
        }
        settings.setIsPhotoRemarks(
            false,
        )
        settings.setIsDescriptionRemarks(
            false,
        )
        settings.setIsRemarksVisible(
            false,
        )
        #expect(
            !settings.getIsPhotoRemarks(),
        )
        #expect(
            !settings.getIsDescriptionRemarks(),
        )
        let root = SubscriptionRootViewModel(
            container: container,
        )
        let first = USExaminationScanPhoto(
            image: UIImage(),
            thumbnail: UIImage(),
        )
        let second = USExaminationScanPhoto(
            image: UIImage(),
            thumbnail: UIImage(),
        )
        let point = USExaminationPhotoRemarkPoint(
            x: 0.5,
            y: 0.5,
            title: "Image finding",
            description: "Image remark",
        )
        let arguments = PhotoViewArguments(
            getPhotos: { [first, second] },
            getPhotoRemarks: { [USExaminationPhotoRemarks(
                photoId: first.id,
                points: [point],
            )] },
            initialPhotoID: first.id,
        )
        let model = makeViewer(
            container: container,
            root: root,
            arguments: arguments,
        )
        #expect(
            !model.isRemarksVisible,
        )
        #expect(
            model.isRemarksToggleVisible,
        )
        #expect(
            model.remarkPoints(
                for: first.id,
            ).first?.id == point.id,
        )
        #expect(
            model.remarkPoints(
                for: second.id,
            ).isEmpty,
        )
        model.setRemarksVisibility(
            true,
        )
        #expect(
            settings.getIsRemarksVisible(),
        )
        model.setRemarksVisibility(
            false,
        )
        #expect(
            !model.isRemarksVisible,
        )
        #expect(
            !settings.getIsRemarksVisible(),
        )
        model.setRemarksVisibility(
            true,
        )
        model.selectedPhotoID = second.id
        #expect(
            !model.isRemarksToggleVisible,
        )
        #expect(
            model.isRemarksVisible,
        )
        let reopened = makeViewer(
            container: container,
            root: root,
            arguments: arguments,
        )
        #expect(
            reopened.isRemarksVisible,
        )
        model.onTapRemark(
            point,
        )
        #expect(
            model.router.sheet?.type == .photoRemark,
        )
        #expect(
            (model.router.sheet?.arguments as? PhotoRemarkArguments)?.title == point.title,
        )
        #expect(
            (model.router.sheet?.arguments as? PhotoRemarkArguments)?.description == point.description,
        )
    }

    private func makeViewer(
        container: DependencyContainer,
        root: SubscriptionRootViewModel,
        arguments: PhotoViewArguments,
    ) -> PhotoViewViewModel {
        PhotoViewViewModel(
            container: container,
            router: DRouter(
                initialRoute: RouteScreen(
                    type: .photoView,
                    arguments: arguments,
                ),
            ),
            getSubscriptionStatus: { root.status },
            observeSubscriptionStatus: { root.observeStatus(
                $0,
            ) },
            onSubscriptionStatusUpdated: { root.update(
                status: $0,
            ) },
            getNeuralModelSettings: { root.neuralModelSettings },
            onRequestCountIncremented: {},
            arguments: arguments,
        )
    }
}
