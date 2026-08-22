import Foundation

final class DefaultMockFactory: MockFactory {
    func fillPatientComplaint(
        for locale: Locale
    ) -> String {
        switch locale.language.languageCode?.identifier {
        case "ru":
            return Self.patientComplaintRU
        case "en":
            return Self.patientComplaintEN
        default:
            return Self.patientComplaintEN
        }
    }

    func fillExaminationDescription(
        for locale: Locale
    ) -> String {
        switch locale.language.languageCode?.identifier {
        case "ru":
            return Self.examinationDescriptionRU
        case "en":
            return Self.examinationDescriptionEN
        default:
            return Self.examinationDescriptionEN
        }
    }
}

private extension DefaultMockFactory {
    static let patientComplaintEN = """
    The patient reports intermittent pressure and discomfort in the anterior neck, \
    occurring mainly in the morning and during physical activity. \
    They report difficulty swallowing solid food that began about three weeks ago. \
    During the last month, the patient has experienced marked general weakness, \
    increased fatigue, and reduced performance later in the day. \
    They occasionally record a low-grade temperature of up to 37.2 °C. \
    They report no weight loss and no previous similar complaints. \
    The family history is negative for thyroid disease.
    """

    static let patientComplaintRU = """
    Пациент предъявляет жалобы на периодическое ощущение давления и дискомфорта в передней области шеи, \
    возникающее преимущественно в утренние часы и при физической нагрузке. \
    Отмечает затруднение при глотании твёрдой пищи, появившееся около трёх недель назад. \
    Со слов пациента, в последний месяц наблюдается выраженная общая слабость, \
    повышенная утомляемость и снижение работоспособности во второй половине дня. \
    Эпизодически фиксирует субфебрильную температуру до 37,2 °C. \
    Потери веса не отмечает. Ранее подобных жалоб не предъявлял. \
    Наследственный анамнез по заболеваниям щитовидной железы не отягощён.
    """

    static let examinationDescriptionEN = """
    A thyroid ultrasound was performed with a linear transducer \
    in standard longitudinal and transverse planes, assessing both lobes and the isthmus. \
    Right lobe: 52×18×16 mm, volume 7.4 mL. Left lobe: 50×17×15 mm, volume 6.3 mL. \
    Total gland volume is 13.7 mL, at the upper limit of normal. \
    The lobe contours are smooth and well defined; the capsule is not thickened. \
    The parenchyma has medium echogenicity and homogeneous structure, with no focal changes. \
    The isthmus measures 4 mm and is unremarkable. \
    Color Doppler flow is symmetrical and not increased. \
    Regional cervical lymph nodes are not enlarged and have normal morphology. \
    The examination was performed on an expert-class stationary ultrasound system \
    using a 7.5–12 MHz multifrequency linear transducer. \
    Visualization quality was good throughout the examination. \
    Key images were archived in DICOM format.
    """

    static let examinationDescriptionRU = """
    Проведено ультразвуковое исследование щитовидной железы линейным датчиком \
    в стандартных продольных и поперечных проекциях с оценкой обеих долей и перешейка. \
    Правая доля: 52×18×16 мм, объём 7,4 мл. Левая доля: 50×17×15 мм, объём 6,3 мл. \
    Общий объём железы — 13,7 мл, что соответствует верхней границе нормы. \
    Контуры долей ровные, чёткие, капсула не утолщена. \
    Эхогенность паренхимы средняя, структура однородная, без очаговых изменений. \
    Перешеек толщиной 4 мм, без особенностей. \
    Кровоток при цветовом допплеровском картировании симметричный, не усилен. \
    Регионарные лимфатические узлы шеи не увеличены, обычной структуры. \
    Исследование выполнено на стационарном ультразвуковом аппарате экспертного класса \
    с использованием линейного мультичастотного датчика 7,5–12 МГц. \
    Качество визуализации хорошее на протяжении всего исследования. \
    Архивирование ключевых изображений выполнено в формате DICOM.
    """
}
