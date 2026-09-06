import Router

extension Coordinator {
    static func initialRoute(
        for context: InitialNavigationContext
    ) throws -> RouteScreen<ScreenType> {
        let applicationConfig = context.applicationConfig
        guard applicationConfig.isServiceAvailable else {
            throw InitializationError.serviceUnavailable(
                email: applicationConfig.contactEmail
            )
        }

        if context.applicationVersion.major < applicationConfig.actualVersion.major,
           !applicationConfig.appStoreId.isEmpty
        {
            return RouteScreen(type: .newVersion)
        }

        guard context.isOnBoardingCompleted,
              context.selectedUSExaminationTypeId != nil
        else {
            return RouteScreen(type: .onBoarding)
        }

        let acceptedLegalDate = context.acceptedLegalDocumentDate ?? .distantPast
        if acceptedLegalDate < applicationConfig.legalDate {
            return RouteScreen(type: .legalUpdate)
        }

        if context.conclusionsCount == 0,
           context.subscriptionStatus == nil
        {
            return RouteScreen(type: .subscriptionPaywall)
        }

        return RouteScreen(type: .scan)
    }
}
