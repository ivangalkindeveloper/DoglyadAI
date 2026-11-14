import Foundation

struct ReportEmail: Encodable, Sendable {
    let recipientEmail: String
    let subject: String
    let body: String
    let attachments: [ReportEmailAttachment]

    init(
        recipientEmail: String,
        subject: String,
        body: String,
        attachments: [ReportEmailAttachment],
    ) {
        self.recipientEmail = recipientEmail
        self.subject = subject
        self.body = body
        self.attachments = attachments
    }
}
