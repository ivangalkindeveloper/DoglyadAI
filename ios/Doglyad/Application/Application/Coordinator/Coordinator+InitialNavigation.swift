import Router

extension Coordinator {
    static func initialRoute(
        for context: InitialNavigationContext
    ) -> RouteScreen<ScreenType> {
        let applicationConfig = context.applicationConfig

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
