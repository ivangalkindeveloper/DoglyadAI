import Router
import SwiftUI

final class RouterBuilder: RouterBuilderProtocol {
    typealias Screen = ScreenType
    typealias Sheet = SheetType
    typealias FullScreenCover = FullScreenCoverType
    typealias Content = AnyView

    func build(
        route: RouteScreen<ScreenType>,
    ) -> AnyView {
        switch route.type {
        case .newVersion:
            AnyView(
                NewVersionScreen(
                    arguments: route.arguments as? NewVersionArguments,
                ),
            )
        case .photoView:
            AnyView(
                PhotoViewScreen(
                    arguments: route.arguments as! PhotoViewArguments,
                ),
            )
        case .onBoarding:
            AnyView(
                OnBoardingScreen(
                    arguments: route.arguments as? OnBoardingArguments,
                ),
            )
        case .legalUpdate:
            AnyView(
                LegalUpdateScreen(
                    arguments: route.arguments as? LegalUpdateArguments,
                ),
            )
        case .scan:
            AnyView(
                ScanScreen(
                    arguments: route.arguments as? ScanArguments,
                ),
            )
        case .history:
            AnyView(
                HistoryScreen(
                    arguments: route.arguments as? HistoryArguments,
                ),
            )
        case .reportDetail:
            AnyView(
                ReportDetailScreen(
                    arguments: route.arguments as! ReportDetailArguments,
                ),
            )
        case .settings:
            AnyView(
                SettingsScreen(
                    arguments: route.arguments as? SettingsArguments,
                ),
            )
        case .settingsAI:
            AnyView(
                SettingsAIScreen(
                    arguments: route.arguments as? SettingsAIArguments,
                ),
            )
        case .templateList:
            AnyView(
                TemplateListScreen(
                    arguments: route.arguments as? TemplateListArguments,
                ),
            )
        case .readyMadeTemplateList:
            AnyView(
                ReadyMadeTemplateListScreen(
                    arguments: route.arguments as! ReadyMadeTemplateListArguments,
                ),
            )
        case .templateAdd:
            AnyView(
                TemplateAddScreen(
                    arguments: route.arguments as? TemplateAddArguments,
                ),
            )
        case .templateEdit:
            AnyView(
                TemplateEditScreen(
                    arguments: route.arguments as! TemplateEditArguments,
                ),
            )
        case .storage:
            AnyView(
                StorageScreen(
                    arguments: route.arguments as? StorageArguments,
                ),
            )
        case .userSettings:
            AnyView(
                UserSettingsScreen(
                    arguments: route.arguments as? UserSettingsArguments,
                ),
            )
        case .subscription:
            AnyView(
                SubscriptionScreen(
                    arguments: route.arguments as? SubscriptionArguments,
                ),
            )
        case .subscriptionPaywall:
            AnyView(
                SubscriptionPaywallScreen(
                    arguments: route.arguments as? SubscriptionPaywallArguments,
                ),
            )
        }
    }

    func build(
        route: RouteSheet<SheetType>,
    ) -> AnyView {
        switch route.type {
        case .importMedia:
            AnyView(
                ImportMediaBottomSheet(
                    arguments: route.arguments as! ImportMediaArguments,
                ),
            )
        case .photoRemark:
            AnyView(
                PhotoRemarkBottomSheet(
                    arguments: route.arguments as! PhotoRemarkArguments,
                ),
            )
        case .scanCamera:
            AnyView(
                ScanCameraBottomSheet(
                    arguments: route.arguments as! ScanCameraArguments,
                ),
            )
        case .selectUSExaminationType:
            AnyView(
                SelectUSExaminationTypeBottomSheet(
                    arguments: route.arguments as? SelectUSExaminationTypeArguments,
                ),
            )
        case .selectTranscriber:
            AnyView(
                SelectTranscriberBottomSheet(
                    arguments: route.arguments as! SelectTranscriberArguments,
                ),
            )
        case .selectTranscriptParser:
            AnyView(
                SelectTranscriptParserBottomSheet(
                    arguments: route.arguments as! SelectTranscriptParserArguments,
                ),
            )
        case .selectNeuralModel:
            AnyView(
                SelectNeuralModelBottomSheet(
                    arguments: route.arguments as? SelectNeuralModelArguments,
                ),
            )
        case .selectTemplate:
            AnyView(
                SelectTemplateBottomSheet(
                    arguments: route.arguments as! SelectTemplateArguments,
                ),
            )
        case .selectDateOfBirth:
            AnyView(
                SelectDateOfBirthBottomSheet(
                    arguments: route.arguments as? SelectDateOfBirthArguments,
                ),
            )
        case .scanSpeech:
            AnyView(
                ScanSpeechBottomSheet(
                    arguments: route.arguments as! ScanSpeechArguments,
                ),
            )
        case .permissionCamera:
            AnyView(
                PermissionBottomSheet(
                    arguments: PermissionArguments(
                        kind: .camera,
                    ),
                ),
            )
        case .permissionSpeech:
            AnyView(
                PermissionBottomSheet(
                    arguments: PermissionArguments(
                        kind: .speech,
                    ),
                ),
            )
        case .permissionPhotoLibrary:
            AnyView(
                PermissionBottomSheet(
                    arguments: PermissionArguments(
                        kind: .photoLibrary,
                    ),
                ),
            )
        case .photoLibraryPicker:
            AnyView(
                PhotoLibraryPickerBottomSheet(
                    arguments: route.arguments as! PhotoLibraryPickerArguments,
                ),
            )
        case .reportReceived:
            AnyView(
                ReportReceivedBottomSheet(
                    arguments: route.arguments as! ReportReceivedArguments,
                ),
            )
        case .webDocument:
            AnyView(
                WebDocumentBottomSheet(
                    arguments: route.arguments as! WebDocumentArguments,
                ),
            )
        case .storageClearProtocols:
            AnyView(
                StorageClearProtocolsBottomSheet(
                    arguments: route.arguments as? StorageClearProtocolsArguments,
                ),
            )
        case .storageClearAll:
            AnyView(
                StorageClearAllBottomSheet(
                    arguments: route.arguments as? StorageClearAllArguments,
                ),
            )
        case .templateDelete:
            AnyView(
                TemplateDeleteBottomSheet(
                    arguments: route.arguments as? TemplateDeleteArguments,
                ),
            )
        case .about:
            AnyView(
                AboutBottomSheet(
                    arguments: AboutArguments(),
                ),
            )
        case .share:
            AnyView(
                ShareBottomSheet(
                    arguments: route.arguments as! ShareArguments,
                ),
            )
        case .requestLimitExceeded:
            AnyView(
                RequestLimitExceededBottomSheet(
                    arguments: route.arguments as? RequestLimitExceededArguments,
                ),
            )
        case .subscriptionCustomerCenter:
            AnyView(
                SubscriptionCustomerCenterBottomSheet(
                    arguments: route.arguments as? SubscriptionCustomerCenterArguments,
                ),
            )
        }
    }

    func build(
        route: RouteFullScreenCover<FullScreenCoverType>,
    ) -> AnyView {
        switch route.type {}
    }
}
