import Foundation

struct SelectUSExaminationTypeItem: Identifiable {
    let id: String
    let type: USExaminationType

    init(
        id: String,
        type: USExaminationType,
    ) {
        self.id = id
        self.type = type
    }
}
