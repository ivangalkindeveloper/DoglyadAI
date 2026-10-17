import Foundation

struct SelectUSExaminationTypeSection: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let items: [SelectUSExaminationTypeItem]

    init(
        id: String,
        title: LocalizedStringResource,
        types: [USExaminationType],
    ) {
        self.id = id
        self.title = title
        items = types.map { type in
            SelectUSExaminationTypeItem(
                id: "\(id):\(type.id)",
                type: type,
            )
        }
    }
}
