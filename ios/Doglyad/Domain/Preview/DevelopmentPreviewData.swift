#if DEBUG
    struct DevelopmentPreviewData: Decodable {
        let application: ApplicationConfig
        let localization: Localization
        let examinationTypes: [USExaminationTypeGroup]
        let neuralModels: [USExaminationNeuralModel]
        let readyMadeTemplates: [USExaminationReadyMadeTemplate]
        let products: BillingProductsResponse
    }
#endif
