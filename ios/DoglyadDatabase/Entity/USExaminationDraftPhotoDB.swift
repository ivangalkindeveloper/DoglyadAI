import Foundation
import SwiftData

@Model
public final class USExaminationDraftPhotoDB {
    public var id: UUID
    public var position: Int
    public var data: Data
    public var thumbnailData: Data?

    public init(
        id: UUID,
        position: Int,
        data: Data,
        thumbnailData: Data?
    ) {
        self.id = id
        self.position = position
        self.data = data
        self.thumbnailData = thumbnailData
    }
}
