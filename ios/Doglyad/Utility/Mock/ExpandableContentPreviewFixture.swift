#if DEBUG
    import Foundation

    struct ExpandableContentPreviewFixture {
        enum Scenario: Hashable {
            case short
            case threeLines
            case fourLines
            case long
            case narrow
            case singleLineLimit
            case markdown
        }

        let text: String
        let width: CGFloat
        let collapsedLineLimit: Int
        let isMarkdown: Bool

        init(
            scenario: Scenario,
        ) {
            text = switch scenario {
            case .short:
                "Без особенностей."
            case .threeLines:
                """
                Печень не увеличена.
                Контуры ровные.
                Структура однородная.
                """
            case .fourLines:
                """
                Печень не увеличена.
                Контуры ровные.
                Структура однородная.
                Очагов не выявлено.
                """
            case .long, .narrow, .singleLineLimit:
                """
                Правая почка расположена обычно, размеры 110 на 48 миллиметров. Контуры ровные, чёткие. Толщина паренхимы 16 миллиметров. Чашечно-лоханочная система не расширена.

                Левая почка расположена обычно, размеры 108 на 46 миллиметров. Контуры ровные, чёткие. Толщина паренхимы 17 миллиметров. Конкременты не определяются. Свободная жидкость не выявлена.
                """
            case .markdown:
                """
                ### Описание исследования

                **Печень** не увеличена, контуры ровные. Структура паренхимы однородная.

                - Желчный пузырь без конкрементов.
                - Внутрипечёночные протоки не расширены.
                - Свободная жидкость не выявлена.

                **Заключение:** эхографических изменений не выявлено.
                """
            }
            width = switch scenario {
            case .narrow: 260
            case .short, .threeLines, .fourLines, .long, .singleLineLimit, .markdown: 360
            }
            collapsedLineLimit = switch scenario {
            case .singleLineLimit: 1
            case .short, .threeLines, .fourLines, .long, .narrow, .markdown: 3
            }
            isMarkdown = switch scenario {
            case .markdown: true
            case .short, .threeLines, .fourLines, .long, .narrow, .singleLineLimit: false
            }
        }
    }
#endif
