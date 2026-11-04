public import Foundation
internal import Alamofire

public enum DHttpFailure {
    public static func statusCode(
        for error: Error,
    ) -> Int? {
        (error as? AFError)?.responseCode
    }
}
