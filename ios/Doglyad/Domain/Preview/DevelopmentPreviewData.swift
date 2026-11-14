#if DEBUG
    struct DevelopmentPreviewData: Decodable {
        let application: ApplicationConfig
        let localization: Localization
        let examinationTypes: [USExaminationTypeGroup]
        let neuralModels: [USExaminationNeuralModel]
        let readyMadeTemplates: [USExaminationReadyMadeTemplate]
        let products: BillingProductsResponse

        init(
            application: ApplicationConfig,
            localization: Localization,
            examinationTypes: [USExaminationTypeGroup],
            neuralModels: [USExaminationNeuralModel],
            readyMadeTemplates: [USExaminationReadyMadeTemplate],
            products: BillingProductsResponse,
        ) {
            self.application = application
            self.localization = localization
            self.examinationTypes = examinationTypes
            self.neuralModels = neuralModels
            self.readyMadeTemplates = readyMadeTemplates
            self.products = products
        }
    }
#endif
