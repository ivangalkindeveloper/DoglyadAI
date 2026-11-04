import Foundation
import SwiftData

@Model
public final class USReportGenerationDB {
    public var status: String
    public var id: UUID?
    @Attribute(
        .externalStorage,
    ) public var requestData: Data?
    public var sequence: Int

    public init(
        status: String,
        id: UUID?,
        requestData: Data?,
        sequence: Int,
    ) {
        self.status = status
        self.id = id
        self.requestData = requestData
        self.sequence = sequence
    }
}
