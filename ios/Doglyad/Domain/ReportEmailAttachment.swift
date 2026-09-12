import Foundation

struct ReportEmailAttachment: Encodable, Sendable {
    let fileName: String
    let mimeType: String
    let data: Data
}
