import Foundation

struct Version: Codable {
    let major: Int
    let minor: Int
    let patch: Int
}

extension Version {
    static let `default` = Version(
        major: 1,
        minor: 0,
        patch: 0
    )
}
