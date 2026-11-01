import Foundation

protocol EnvironmentProtocol: AnyObject {
    var type: EnvironmentType {
        get
    }
    var baseUrl: URL {
        get
    }
    var baseVersionPrefix: String {
        get
    }
}
