import Foundation

struct Version: Codable {
    let major: Int
    let minor: Int
    let patch: Int

    init(
        major: Int,
        minor: Int,
        patch: Int,
    ) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}

extension Version {
    static let `default` = Version(
        major: 1,
        minor: 0,
        patch: 0,
    )
}
