import Foundation

struct ReportEmailAttachment: Encodable, Sendable {
    let fileName: String
    let mimeType: String
    let data: Data

    init(
        fileName: String,
        mimeType: String,
        data: Data,
    ) {
        self.fileName = fileName
        self.mimeType = mimeType
        self.data = data
    }
}
