enum ScreenType: Hashable {
    case photoView
    case newVersion
    case onBoarding
    case legalUpdate
    case scan
    case history
    case reportDetail
    case settings
    case settingsAI
    case templateList
    case readyMadeTemplateList
    case templateAdd
    case templateEdit
    case storage
    case userSettings
    case subscriptionRecovery
    case manageSubscription
    case paywall
}

enum SheetType: Hashable {
    case photoRemark
    case importMedia
    case scanCamera
    case selectUSExaminationType
    case selectTranscriber
    case selectTranscriptParser
    case selectNeuralModel
    case selectTemplate
    case selectDateOfBirth
    case scanSpeech
    case requestLimitExceeded
    case permissionCamera
    case permissionSpeech
    case permissionPhotoLibrary
    case photoLibraryPicker
    case reportReceived
    case webDocument
    case storageClearProtocols
    case storageClearAll
    case templateDelete
    case about
    case share
}

enum FullScreenCoverType: Hashable {}
