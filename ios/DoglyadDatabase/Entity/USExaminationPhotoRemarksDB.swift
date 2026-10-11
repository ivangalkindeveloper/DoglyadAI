import Foundation
import SwiftData

@Model
public final class USExaminationPhotoRemarksDB {
    public var photoId: UUID
    @Relationship(
        deleteRule: .cascade,
    ) public var points: [USExaminationPhotoRemarkPointDB] = []

    public init(
        photoId: UUID,
        points: [USExaminationPhotoRemarkPointDB],
    ) {
        self.photoId = photoId
        self.points = points
    }
}
