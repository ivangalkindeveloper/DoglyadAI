import Router
import SwiftUI

final class RouterBuilder: RouterBuilderProtocol {
    typealias Screen = ScreenType
    typealias Sheet = SheetType
    typealias FullScreenCover = FullScreenCoverType
    typealias Content = AnyView

    func build(
        route: RouteScreen<ScreenType>
    ) -> AnyView {
        switch route.type {
        case .newVersion:
            AnyView(NewVersionScreen(arguments: route.arguments as? NewVersionScreenArguments))
        case .onBoarding:
            AnyView(OnBoardingScreen(arguments: route.arguments as? OnBoardingScreenArguments))
        case .legalUpdate:
            AnyView(LegalUpdateScreen(arguments: route.arguments as? LegalUpdateScreenArguments))
        case .scan:
            AnyView(ScanScreen(arguments: route.arguments as? ScanScreenArguments))
        case .history:
            AnyView(HistoryScreen(arguments: route.arguments as? HistoryScreenArguments))
        case .reportDetail:
            AnyView(ReportDetailScreen(arguments: route.arguments as! ReportDetailScreenArguments))
        case .settings:
            AnyView(SettingsScreen(arguments: route.arguments as? SettingsScreenArguments))
        case .neuralModelSettings:
            AnyView(NeuralModelSettingsScreen(arguments: route.arguments as? NeuralModelSettingsScreenArguments))
        case .templateList:
            AnyView(TemplateListScreen(arguments: route.arguments as? TemplateListScreenArguments))
        case .readyMadeTemplateList:
            AnyView(ReadyMadeTemplateListScreen(arguments: route.arguments as! ReadyMadeTemplateListScreenArguments))
        case .templateAdd:
            AnyView(TemplateAddScreen(arguments: route.arguments as? TemplateAddScreenArguments))
        case .templateEdit:
            AnyView(TemplateEditScreen(arguments: route.arguments as! TemplateEditScreenArguments))
        case .storage:
            AnyView(StorageScreen(arguments: route.arguments as? StorageScreenArguments))
        case .userSettings:
            AnyView(UserSettingsScreen(arguments: route.arguments as? UserSettingsScreenArguments))
        case .subscription:
            AnyView(SubscriptionScreen(arguments: route.arguments as? SubscriptionScreenArguments))
        case .subscriptionPaywall:
            AnyView(SubscriptionPaywallScreen(arguments: route.arguments as? SubscriptionPaywallArguments))
        }
    }

    func build(
        route: RouteSheet<SheetType>
    ) -> AnyView {
        switch route.type {
        case .scanCamera:
            AnyView(ScanCameraBottomSheet(arguments: route.arguments as! ScanCameraArguments))
        case .selectUSExaminationType:
            AnyView(SelectUSExaminationTypeBottomSheet(
                arguments: route.arguments as? SelectUSExaminationTypeArguments
            ))
        case .selectNeuralModel:
            AnyView(SelectNeuralModelBottomSheet(arguments: route.arguments as? SelectNeuralModelArguments))
        case .selectTemplate:
            AnyView(SelectTemplateBottomSheet(arguments: route.arguments as! SelectTemplateArguments))
        case .selectDateOfBirth:
            AnyView(SelectDateOfBirthBottomSheet(arguments: route.arguments as? SelectDateOfBirthArguments))
        case .scanSpeech:
            AnyView(ScanSpeechBottomSheet(arguments: route.arguments as! ScanSpeechBottomSheetArguments))
        case .permissionCamera:
            AnyView(PermissionCameraBottomSheet())
        case .permissionSpeech:
            AnyView(PermissionSpeechBottomSheet())
        case .permissionPhotoLibrary:
            AnyView(PermissionPhotoLibraryBottomSheet())
        case .photoLibraryPicker:
            AnyView(PhotoLibraryPicker(arguments: route.arguments as! PhotoLibraryPickerArguments))
        case .reportReceived:
            AnyView(ReportReceivedBottomSheet(
                arguments: route.arguments as! ReportReceivedBottomSheetArguments
            ))
        case .webDocument:
            AnyView(WebDocumentBottomSheet(arguments: route.arguments as! WebDocumentBottomSheetArguments))
        case .storageClearProtocols:
            AnyView(StorageClearProtocolsBottomSheet(
                arguments: route.arguments as? StorageClearProtocolsArguments
            ))
        case .storageClearAll:
            AnyView(StorageClearAllBottomSheet(arguments: route.arguments as? StorageClearAllArguments))
        case .templateDelete:
            AnyView(TemplateDeleteBottomSheet(arguments: route.arguments as? TemplateDeleteArguments))
        case .about:
            AnyView(AboutBottomSheet())
        case .share:
            AnyView(ShareBottomSheet(arguments: route.arguments as! ShareArguments))
        case .requestLimitExceeded:
            AnyView(RequestLimitExceededBottomSheet(
                arguments: route.arguments as? RequestLimitExceededArguments
            ))
        case .subscriptionCustomerCenter:
            AnyView(SubscriptionCustomerCenterSheet(
                arguments: route.arguments as? SubscriptionCustomerCenterArguments
            ))
        }
    }

    func build(
        route: RouteFullScreenCover<FullScreenCoverType>
    ) -> AnyView {
        switch route.type {}
    }
}
