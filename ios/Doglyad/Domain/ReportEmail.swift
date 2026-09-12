import Foundation

struct ReportEmail: Encodable, Sendable {
    let recipientEmail: String
    let subject: String
    let body: String
    let attachments: [ReportEmailAttachment]
}
