enum ScreenType: Hashable {
    case newVersion
    case onBoarding
    case legalUpdate
    case scan
    case history
    case reportDetail
    case settings
    case neuralModelSettings
    case templateList
    case templateAdd
    case templateEdit
    case storage
    case userSettings
    case subscription
    case subscriptionPaywall
}

enum SheetType: Hashable {
    case selectUSExaminationType
    case selectNeuralModel
    case selectDateOfBirth
    case scanSpeech
    case requestLimitExceeded
    case permissionSpeech
    case permissionPhotoLibrary
    case photoLibraryPicker
    case receivedReport
    case webDocument
    case storageClearConclusions
    case storageClearAll
    case about
    case share
    case subscriptionCustomerCenter
}

enum FullScreenCoverType: Hashable {}
