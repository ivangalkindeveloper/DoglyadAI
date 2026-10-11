import Foundation
import SwiftData

@Model
public final class USExaminationPhotoRemarkPointDB {
    public var id: UUID
    public var x: Double
    public var y: Double
    public var title: String
    // SwiftData's @Model macro reserves the stored-property name `description`.
    public var remarkDescription: String

    public init(
        id: UUID,
        x: Double,
        y: Double,
        title: String,
        remarkDescription: String,
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.title = title
        self.remarkDescription = remarkDescription
    }
}
