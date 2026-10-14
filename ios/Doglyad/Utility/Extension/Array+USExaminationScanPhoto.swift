import DoglyadDatabase
import UIKit

extension [USExaminationScanPhoto] {
    func toDraftDB() -> [USExaminationDraftPhotoDB] {
        enumerated().compactMap { index, photo in
            photo.toDraftDB(
                position: index,
            )
        }
    }
}
