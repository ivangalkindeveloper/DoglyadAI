import Foundation

extension Error {
    @MainActor
    func isEqual(
        to other: any Error,
    ) -> Bool {
        if let error = (self as Any) as? any Equatable {
            return error.isEqual(
                to: other,
            )
        }
        if type(
            of: self,
        ) is NSError.Type, type(
            of: other,
        ) is NSError.Type {
            return (self as NSError).isEqual(
                other as NSError,
            )
        }
        guard type(
            of: self,
        ) is AnyClass, type(
            of: other,
        ) is AnyClass else { return false }
        return (self as AnyObject) === (other as AnyObject)
    }
}
