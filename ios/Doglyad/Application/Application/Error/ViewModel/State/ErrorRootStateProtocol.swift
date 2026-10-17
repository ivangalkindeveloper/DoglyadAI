import Foundation

@MainActor
protocol ErrorRootStateProtocol: AnyObject { var error: Error { get } }
