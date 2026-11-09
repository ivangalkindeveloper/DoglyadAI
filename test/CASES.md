# Регресс-кейсы

Описание сценариев каждого модуля и статус автоматизации: [COVERAGE.md](COVERAGE.md). Ниже перечислены исполняемые flows и отдельные Preview-снимки.

Список создаёт `python3 test/scripts/catalog.py`. Это перечень проверок, а не результат запуска.

Платформа: iOS. Модулей: 41. Функциональных кейсов с вводным сценарием: 129. Кейсов отображения: 231.

## Функциональные сценарии

Выполняются в указанном порядке на новом стенде. YAML содержит шаги и ожидаемый результат.

| Кейс | Проверка | Снимков |
|---|---|---|
| [bootstrap-onboarding](modules/OnBoarding/e2e/bootstrap.yaml) | Первый запуск: onboarding, согласие, выбор исследования и paywall | 7 |
| [e2e-history-history-empty](modules/History/e2e/history-empty.yaml) | История пуста на новом стенде | 1 |
| [e2e-reportreceived-generation](modules/ReportReceived/e2e/generation.yaml) | Сгенерировать и открыть протокол через локальный backend | 4 |
| [e2e-reportreceived-partial-retry](modules/ReportReceived/e2e/partial-retry.yaml) | Ошибка генерации и успешный повтор: fail-after-preview | 3 |
| [e2e-reportreceived-failure-retry](modules/ReportReceived/e2e/failure-retry.yaml) | Ошибка генерации и успешный повтор: fail-before | 3 |
| [e2e-history-pending-generation](modules/History/e2e/pending-generation.yaml) | Открыть выполняющийся отчёт из истории и дождаться завершения после возврата в приложение | 3 |
| [e2e-scan-draft-persistence](modules/Scan/e2e/draft-persistence.yaml) | Черновик сохраняется после перезапуска | 1 |
| [e2e-selectdateofbirth-confirm-cancel](modules/SelectDateOfBirth/e2e/confirm-cancel.yaml) | Подтверждение даты рождения, отмена и сохранение после перезапуска | 2 |
| [e2e-scan-gender-persistence](modules/Scan/e2e/gender-persistence.yaml) | Выбор пола и сохранение после перезапуска | 2 |
| [e2e-scan-development-fill-return](modules/Scan/e2e/development-fill-return.yaml) | DEV-заполнение и возврат из настроек | 1 |
| [e2e-scan-clear-draft](modules/Scan/e2e/clear-draft.yaml) | Очистка и перезапуск черновика | 1 |
| [e2e-scan-validation-empty](modules/Scan/e2e/validation-empty.yaml) | Пустое описание блокирует генерацию до HTTP-запроса | 1 |
| [e2e-scan-initialization-retry](modules/Scan/e2e/initialization-retry.yaml) | Ошибка загрузки Scan сохраняет черновик | 2 |
| [e2e-scan-draft-save-retry](modules/Scan/e2e/draft-save-retry.yaml) | Ошибка записи черновика и повторное сохранение | 2 |
| [e2e-scan-generation-save-retry](modules/Scan/e2e/generation-save-retry.yaml) | Ошибка записи отчёта перед генерацией и успешный повтор | 2 |
| [e2e-selectusexaminationtype-choose-persist](modules/SelectUSExaminationType/e2e/choose-persist.yaml) | Выбор типа и сохранение | 1 |
| [e2e-selectusexaminationtype-failures](modules/SelectUSExaminationType/e2e/failures.yaml) | Ошибка чтения и выбора типа: сохранить прежний выбор и повторить | 2 |
| [e2e-history-saved-report](modules/History/e2e/saved-report.yaml) | Сгенерировать отчёт и открыть из истории после перезапуска | 1 |
| [e2e-history-pagination](modules/History/e2e/pagination.yaml) | 41 сохранённый протокол: три страницы, группы дат и перезапуск | 5 |
| [e2e-menu-history-summary-retry](modules/Menu/e2e/history-summary-retry.yaml) | Недоступный счётчик истории не блокирует настройки | 2 |
| [e2e-menu-navigation](modules/Menu/e2e/navigation.yaml) | Все пункты настроек в порядке экрана и возврат без изменений | 2 |
| [e2e-history-load-failures](modules/History/e2e/load-failures.yaml) | Ошибка первой и следующей страниц истории | 3 |
| [e2e-templateadd-template-create](modules/TemplateAdd/e2e/template-create.yaml) | Создать шаблон и проверить сохранение | 1 |
| [e2e-templateadd-cancel](modules/TemplateAdd/e2e/cancel.yaml) | Выход без создания шаблона | 1 |
| [e2e-templateadd-save-failure](modules/TemplateAdd/e2e/save-failure.yaml) | Ошибка сохранения шаблона, повтор и отсутствие дубля | 2 |
| [e2e-templatelist-load-failure](modules/TemplateList/e2e/load-failure.yaml) | Ошибка загрузки шаблонов и повтор | 2 |
| [e2e-templatelist-two-types](modules/TemplateList/e2e/two-types.yaml) | Два шаблона разных типов: открыть, вернуться и перезапустить | 1 |
| [e2e-templateedit-template-edit](modules/TemplateEdit/e2e/template-edit.yaml) | Изменить шаблон и проверить сохранение после перезапуска | 1 |
| [e2e-templateedit-cancel](modules/TemplateEdit/e2e/cancel.yaml) | Выход без изменения сохранённого шаблона | 1 |
| [e2e-readymadetemplatelist-ready-templates](modules/ReadyMadeTemplateList/e2e/ready-templates.yaml) | Найти готовый шаблон, применить и проверить сохранённое содержимое | 2 |
| [e2e-readymadetemplatelist-empty-failure-cancel](modules/ReadyMadeTemplateList/e2e/empty-failure-cancel.yaml) | Пустой каталог, ошибка загрузки и отмена выбора | 3 |
| [e2e-selecttemplate-apply-reset](modules/SelectTemplate/e2e/apply-reset.yaml) | Выбрать сохранённый шаблон, перезапустить и сбросить | 2 |
| [e2e-selecttemplate-type-filter-failure](modules/SelectTemplate/e2e/type-filter-failure.yaml) | Шаблон другого типа, пустой список и повтор после ошибки чтения | 3 |
| [e2e-scan-clear-media-template](modules/Scan/e2e/clear-media-template.yaml) | Очистить фото и поля, сохранив историю, шаблоны и выбранный шаблон | 2 |
| [e2e-templatedelete-cancel](modules/TemplateDelete/e2e/cancel.yaml) | Отмена удаления сохраняет шаблон | 1 |
| [e2e-templatedelete-delete-template](modules/TemplateDelete/e2e/delete-template.yaml) | Удалить созданный тестом шаблон | 2 |
| [e2e-worksettings-work-settings](modules/WorkSettings/e2e/work-settings.yaml) | Рабочий email сохраняется после перезапуска | 1 |
| [e2e-worksettings-flags-000](modules/WorkSettings/e2e/flags-000.yaml) | Переключатели: 000 сохраняются после перезапуска | 2 |
| [e2e-worksettings-flags-001](modules/WorkSettings/e2e/flags-001.yaml) | Переключатели: 001 сохраняются после перезапуска | 2 |
| [e2e-worksettings-flags-010](modules/WorkSettings/e2e/flags-010.yaml) | Переключатели: 010 сохраняются после перезапуска | 2 |
| [e2e-worksettings-flags-011](modules/WorkSettings/e2e/flags-011.yaml) | Переключатели: 011 сохраняются после перезапуска | 2 |
| [e2e-worksettings-flags-100](modules/WorkSettings/e2e/flags-100.yaml) | Переключатели: 100 сохраняются после перезапуска | 2 |
| [e2e-worksettings-flags-101](modules/WorkSettings/e2e/flags-101.yaml) | Переключатели: 101 сохраняются после перезапуска | 2 |
| [e2e-worksettings-flags-110](modules/WorkSettings/e2e/flags-110.yaml) | Переключатели: 110 сохраняются после перезапуска | 2 |
| [e2e-worksettings-flags-111](modules/WorkSettings/e2e/flags-111.yaml) | Переключатели: 111 сохраняются после перезапуска | 2 |
| [e2e-worksettings-invalid-email](modules/WorkSettings/e2e/invalid-email.yaml) | Неверная почта не заменяет сохранённую | 1 |
| [e2e-worksettings-save-failure](modules/WorkSettings/e2e/save-failure.yaml) | Отмена правки почты, ошибка записи и повтор | 2 |
| [e2e-settingsai-ai-settings](modules/SettingsAI/e2e/ai-settings.yaml) | Открыть настройки и выбор транскрибатора | 2 |
| [e2e-settingsai-providers](modules/SettingsAI/e2e/providers.yaml) | Выбрать WhisperKit и серверный парсер и сохранить | 1 |
| [e2e-settingsai-parameters-0-1](modules/SettingsAI/e2e/parameters-0-1.yaml) | Сохранить температуру 0 и 1 токенов | 1 |
| [e2e-settingsai-parameters-0_7-1024](modules/SettingsAI/e2e/parameters-0_7-1024.yaml) | Сохранить температуру 0.7 и 1024 токенов | 1 |
| [e2e-settingsai-request-parameters](modules/SettingsAI/e2e/request-parameters.yaml) | Параметры AI и полный шаблон доходят до задания backend | 2 |
| [e2e-scan-template-model-request](modules/Scan/e2e/template-model-request.yaml) | Из Scan: сброс/выбор шаблона, модель и AI-параметры реального запроса | 2 |
| [e2e-settingsai-save-failure](modules/SettingsAI/e2e/save-failure.yaml) | Ошибка сохранения параметров модели и повтор | 2 |
| [e2e-settingsai-parameters-2-4096](modules/SettingsAI/e2e/parameters-2-4096.yaml) | Сохранить температуру 2 и 4096 токенов | 1 |
| [e2e-settingsai-temperature-high](modules/SettingsAI/e2e/temperature-high.yaml) | Отклонить недопустимое значение 2.1 | 1 |
| [e2e-settingsai-tokens-zero](modules/SettingsAI/e2e/tokens-zero.yaml) | Отклонить недопустимое значение 0 | 1 |
| [e2e-settingsai-tokens-high](modules/SettingsAI/e2e/tokens-high.yaml) | Отклонить недопустимое значение 4097 | 1 |
| [e2e-settingsai-markdown-false](modules/SettingsAI/e2e/markdown-false.yaml) | Сохранить Markdown False | 1 |
| [e2e-settingsai-markdown-true](modules/SettingsAI/e2e/markdown-true.yaml) | Сохранить Markdown True | 1 |
| [e2e-settingsai-base-restrictions](modules/SettingsAI/e2e/base-restrictions.yaml) | Base блокирует настройки генерации | 1 |
| [e2e-scan-base-voice-gate](modules/Scan/e2e/base-voice-gate.yaml) | Голосовой ввод требует Pro | 1 |
| [e2e-selecttranscriptparser-parser-selector](modules/SelectTranscriptParser/e2e/parser-selector.yaml) | Открыть выбор парсера транскрипта | 1 |
| [e2e-selectneuralmodel-model-1](modules/SelectNeuralModel/e2e/model-1.yaml) | Выбрать Google MedGemma 4B и проверить после перезапуска | 1 |
| [e2e-selectneuralmodel-model-2](modules/SelectNeuralModel/e2e/model-2.yaml) | Выбрать Google MedGemma 1.5 4B и проверить после перезапуска | 1 |
| [e2e-selectneuralmodel-model-3](modules/SelectNeuralModel/e2e/model-3.yaml) | Выбрать Google MedGemma 27B и проверить после перезапуска | 1 |
| [e2e-managesubscription-subscription](modules/ManageSubscription/e2e/subscription.yaml) | Проверить подготовленную тестовую подписку | 1 |
| [e2e-managesubscription-profile-base](modules/ManageSubscription/e2e/profile-base.yaml) | Активная подписка base | 1 |
| [e2e-managesubscription-profile-pro](modules/ManageSubscription/e2e/profile-pro.yaml) | Активная подписка pro | 1 |
| [e2e-managesubscription-support-refund](modules/ManageSubscription/e2e/support-refund.yaml) | Поддержка и запрос возврата не меняют подписку | 1 |
| [e2e-paywall-none](modules/Paywall/e2e/none.yaml) | Paywall при профиле none | 1 |
| [e2e-requestlimitexceeded-limit](modules/RequestLimitExceeded/e2e/limit.yaml) | Проверить серверное ограничение: exhausted | 2 |
| [e2e-managesubscription-background-before-revocation](modules/ManageSubscription/e2e/background-before-revocation.yaml) | Активная Pro перед отзывом доступа в фоне | 1 |
| [e2e-managesubscription-revoked](modules/ManageSubscription/e2e/revoked.yaml) | Проверить серверное ограничение: revoked | 2 |
| [e2e-paywall-expired](modules/Paywall/e2e/expired.yaml) | Paywall при профиле expired | 1 |
| [e2e-paywall-select-base_annual](modules/Paywall/e2e/select-base_annual.yaml) | Выбор base_annual без покупки | 1 |
| [e2e-paywall-select-base_six_months](modules/Paywall/e2e/select-base_six_months.yaml) | Выбор base_six_months без покупки | 1 |
| [e2e-paywall-select-base_monthly](modules/Paywall/e2e/select-base_monthly.yaml) | Выбор base_monthly без покупки | 1 |
| [e2e-paywall-select-base_weekly](modules/Paywall/e2e/select-base_weekly.yaml) | Выбор base_weekly без покупки | 1 |
| [e2e-paywall-select-pro_annual](modules/Paywall/e2e/select-pro_annual.yaml) | Выбор pro_annual без покупки | 1 |
| [e2e-paywall-select-pro_six_months](modules/Paywall/e2e/select-pro_six_months.yaml) | Выбор pro_six_months без покупки | 1 |
| [e2e-paywall-select-pro_monthly](modules/Paywall/e2e/select-pro_monthly.yaml) | Выбор pro_monthly без покупки | 1 |
| [e2e-paywall-select-pro_weekly](modules/Paywall/e2e/select-pro_weekly.yaml) | Выбор pro_weekly без покупки | 1 |
| [e2e-paywall-documents](modules/Paywall/e2e/documents.yaml) | Документы из Paywall сохраняют выбор плана | 2 |
| [e2e-subscriptionrecovery-recovery](modules/SubscriptionRecovery/e2e/recovery.yaml) | Создать ключ восстановления тестовой подписки | 1 |
| [e2e-storageclearprotocols-cancel](modules/StorageClearProtocols/e2e/cancel.yaml) | Отмена очистки сохраняет историю | 2 |
| [e2e-storageclearall-cancel](modules/StorageClearAll/e2e/cancel.yaml) | Отмена очистки сохраняет историю | 2 |
| [e2e-storage-delete-speech-model](modules/Storage/e2e/delete-speech-model.yaml) | Удаление локальной речевой модели и повторная подготовка | 4 |
| [e2e-storage-clear-failure-cancel](modules/Storage/e2e/clear-failure-cancel.yaml) | Сбой очистки и отмена операции при уходе с экрана | 2 |
| [e2e-storageclearprotocols-storage-clear-history](modules/StorageClearProtocols/e2e/storage-clear-history.yaml) | Очистить историю и проверить пустой список | 3 |
| [e2e-webdocument-privacy](modules/WebDocument/e2e/privacy.yaml) | Открыть документ Политика конфиденциальности | 2 |
| [e2e-webdocument-terms](modules/WebDocument/e2e/terms.yaml) | Открыть документ Условия и Положения | 2 |
| [e2e-webdocument-network-failure](modules/WebDocument/e2e/network-failure.yaml) | Ошибка загрузки документа и повторное открытие | 2 |
| [e2e-legalupdate-accept-retry](modules/LegalUpdate/e2e/accept-retry.yaml) | Повторное согласие с документами и ошибка сохранения | 4 |
| [e2e-about-about](modules/About/e2e/about.yaml) | Открыть сведения о приложении | 1 |
| [e2e-about-contact](modules/About/e2e/contact.yaml) | Контактный адрес и версия приложения | 1 |
| [e2e-newversion-required-update](modules/NewVersion/e2e/required-update.yaml) | Обязательное major-обновление и совместимая minor-версия | 2 |
| [e2e-scancamera-capture-delete](modules/ScanCamera/e2e/capture-delete.yaml) | Захват трёх фото и удаление через PhotoView | 4 |
| [e2e-photolibrarypicker-selection-limit](modules/PhotoLibraryPicker/e2e/selection-limit.yaml) | Галерея: выбор, отмена, порядок и лимит снимков | 9 |
| [e2e-permission-gallery](modules/Permission/e2e/gallery.yaml) | Разрешение медиатеки: отказ и возврат из настроек | 3 |
| [e2e-permission-speech](modules/Permission/e2e/speech.yaml) | Разрешение микрофона: отказ и возврат из настроек | 3 |
| [e2e-permission-camera](modules/Permission/e2e/camera.yaml) | Разрешение камеры: отказ и возврат из настроек | 3 |
| [e2e-scancamera-limit-reopen](modules/ScanCamera/e2e/limit-reopen.yaml) | Лимит шести снимков и повторное открытие камеры | 2 |
| [e2e-templateedit-failures](modules/TemplateEdit/e2e/failures.yaml) | Ошибки чтения и сохранения шаблона | 3 |
| [e2e-photoview-report-remarks](modules/PhotoView/e2e/report-remarks.yaml) | Замечания backend, масштабирование и видимость | 4 |
| [e2e-scanspeech-record-review](modules/ScanSpeech/e2e/record-review.yaml) | Ошибка подготовки, диктовка и выбор полей | 5 |
| [e2e-scanspeech-parsing-retry](modules/ScanSpeech/e2e/parsing-retry.yaml) | Ошибка разбора, повтор, пустой транскрипт и перезапись | 4 |
| [e2e-scanspeech-cancel](modules/ScanSpeech/e2e/cancel.yaml) | Отмена записи и разбора без изменения черновика | 3 |
| [e2e-reportreceived-delivery-retry](modules/ReportReceived/e2e/delivery-retry.yaml) | Копирование ответа и повтор реальной доставки из окна получения | 3 |
| [e2e-share-delivery-retry](modules/Share/e2e/delivery-retry.yaml) | Копирование и SMTP: содержимое, вложение, ошибка и повтор | 3 |
| [e2e-share-external-email](modules/Share/e2e/external-email.yaml) | Письмо совпадает с SMTP; отмена и отсутствие рабочего адреса | 2 |
| [e2e-share-base-email-gate](modules/Share/e2e/base-email-gate.yaml) | Base блокирует оба способа отправки по почте | 2 |
| [e2e-reportdetail-saved-report](modules/ReportDetail/e2e/saved-report.yaml) | Сохранённые поля, фото, полный текст и копирование ответа | 2 |
| [e2e-reportdetail-regenerate-retry](modules/ReportDetail/e2e/regenerate-retry.yaml) | Повтор другим AI: ошибка, сохранность старого ответа, успешный повтор | 3 |
| [e2e-reportdetail-copy-previous](modules/ReportDetail/e2e/copy-previous.yaml) | Копирование предыдущей версии и меню доставки отчёта | 2 |
| [e2e-storageclearall-clear-all](modules/StorageClearAll/e2e/clear-all.yaml) | Полная локальная очистка и повторное прохождение onboarding | 5 |
| [e2e-paywall-yookassa-cancel](modules/Paywall/e2e/yookassa-cancel.yaml) | Отмена оплаты в настоящем SDK ЮКассы не выдаёт доступ | 3 |
| [e2e-paywall-yookassa-declined](modules/Paywall/e2e/yookassa-declined.yaml) | YooKassa: реальный отказ тестовой карты без выдачи доступа | 3 |
| [e2e-paywall-yookassa-declined-retry](modules/Paywall/e2e/yookassa-declined-retry.yaml) | Повтор после отказа YooKassa: тот же продукт, отмена без второго платежа | 2 |
| [e2e-paywall-yookassa-base](modules/Paywall/e2e/yookassa-base.yaml) | Покупка Base через SDK тестового магазина YooKassa | 3 |
| [e2e-paywall-yookassa-active-rejected](modules/Paywall/e2e/yookassa-active-rejected.yaml) | Активная Base блокирует новую покупку без дополнительного платежа | 3 |
| [e2e-paywall-yookassa-pending](modules/Paywall/e2e/yookassa-pending.yaml) | Платёж с 3-D Secure остаётся pending без выдачи доступа | 5 |
| [e2e-paywall-yookassa-confirmed](modules/Paywall/e2e/yookassa-confirmed.yaml) | Подтвердить прежний платёж после перезапуска без второго заказа | 3 |
| [e2e-paywall-yookassa-pro](modules/Paywall/e2e/yookassa-pro.yaml) | Покупка Pro через SDK тестового магазина YooKassa | 3 |
| [e2e-managesubscription-cancel-renewal](modules/ManageSubscription/e2e/cancel-renewal.yaml) | Отмена продления сохраняет оплаченный доступ YooKassa | 1 |
| [e2e-subscriptionrecovery-create-key](modules/SubscriptionRecovery/e2e/create-key.yaml) | Копирование ключа настоящей тестовой подписки | 1 |
| [e2e-subscriptionrecovery-rotate-key](modules/SubscriptionRecovery/e2e/rotate-key.yaml) | Замена ключа восстановления | 1 |
| [e2e-subscriptionrecovery-reject-old-key](modules/SubscriptionRecovery/e2e/reject-old-key.yaml) | Старый ключ не даёт доступ чистому клиенту | 1 |
| [e2e-subscriptionrecovery-restore-key](modules/SubscriptionRecovery/e2e/restore-key.yaml) | Новый ключ восстанавливает прежний оплаченный период | 1 |

## Отображение модулей

Каждый кейс запускает существующий полноэкранный Preview модуля, проверяет его идентификатор и делает снимок.
Эти кейсы не проверяют переходы в состояния или работу внешних интеграций. Ограничения описаны в [README](README.md#покрытие-и-ограничения).

| Модуль | Состояние и YAML | Исходник |
|---|---|---|
| ApplicationSplash | [01 ApplicationRootInitialState Splash](modules/ApplicationSplash/atlas/atlas-applicationsplash-0eb7f8db6f.yaml) | [Preview](../ios/Doglyad/Application/Application/Application/Preview/ApplicationSplashPreview.swift) |
| ApplicationSplash | [02 ErrorRootOfflineErrorState Offline](modules/ApplicationSplash/atlas/atlas-applicationsplash-38718e5fbd.yaml) | [Preview](../ios/Doglyad/Application/Application/Application/Preview/ApplicationSplashPreview.swift) |
| ApplicationSplash | [03 ApplicationRootLoadingState RetryingInitialization](modules/ApplicationSplash/atlas/atlas-applicationsplash-0ca6a5fe47.yaml) | [Preview](../ios/Doglyad/Application/Application/Application/Preview/ApplicationSplashPreview.swift) |
| ApplicationSplash | [04 ErrorRootServiceUnavailableErrorState ServiceUnavailable](modules/ApplicationSplash/atlas/atlas-applicationsplash-1e6d7a2807.yaml) | [Preview](../ios/Doglyad/Application/Application/Application/Preview/ApplicationSplashPreview.swift) |
| ApplicationSplash | [05 ErrorRootUnknownErrorState InitializationFailed](modules/ApplicationSplash/atlas/atlas-applicationsplash-7db4e56f75.yaml) | [Preview](../ios/Doglyad/Application/Application/Application/Preview/ApplicationSplashPreview.swift) |
| NewVersion | [01 NewVersionDefaultState MandatoryUpdate](modules/NewVersion/atlas/atlas-newversion-b0db3d70bb.yaml) | [Preview](../ios/Doglyad/Application/Module/NewVersion/Preview/NewVersionPreview.swift) |
| LegalUpdate | [01 LegalUpdateAwaitingAcceptanceState ConsentNotSelected](modules/LegalUpdate/atlas/atlas-legalupdate-cb7d1da5b1.yaml) | [Preview](../ios/Doglyad/Application/Module/LegalUpdate/Preview/LegalUpdatePreview.swift) |
| LegalUpdate | [02 LegalUpdateAwaitingAcceptanceState ConsentSelected](modules/LegalUpdate/atlas/atlas-legalupdate-590379a493.yaml) | [Preview](../ios/Doglyad/Application/Module/LegalUpdate/Preview/LegalUpdatePreview.swift) |
| LegalUpdate | [03 LegalUpdateErrorState ConsentSaveFailed](modules/LegalUpdate/atlas/atlas-legalupdate-3452d0e956.yaml) | [Preview](../ios/Doglyad/Application/Module/LegalUpdate/Preview/LegalUpdatePreview.swift) |
| OnBoarding | [01 OnBoardingInitialState Welcome](modules/OnBoarding/atlas/atlas-onboarding-19535a4434.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [02 OnBoardingSecondState Features](modules/OnBoarding/atlas/atlas-onboarding-fe3c1cdc93.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [03 OnBoardingLegalState ConsentNotSelected](modules/OnBoarding/atlas/atlas-onboarding-491becba21.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [04 OnBoardingLegalState ConsentSelected](modules/OnBoarding/atlas/atlas-onboarding-6ecb6a6c5d.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [05 OnBoardingExaminationTypeState ChooseExaminationType](modules/OnBoarding/atlas/atlas-onboarding-59c97e15d6.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [06 OnBoardingFinalState ReadyToStart](modules/OnBoarding/atlas/atlas-onboarding-1497b1a855.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [07 OnBoardingLoadingState SavingPreferences](modules/OnBoarding/atlas/atlas-onboarding-eb0f86e294.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [08 OnBoardingErrorState PreferencesSaveFailed](modules/OnBoarding/atlas/atlas-onboarding-0648054afd.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| WebDocument | [01 WebDocumentLoadingState LoadingDocument](modules/WebDocument/atlas/atlas-webdocument-8c7dd0d9f5.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [02 WebDocumentLoadingState LoadingDocument ScrollEnd](modules/WebDocument/atlas/atlas-webdocument-d973c83316.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [03 WebDocumentSuccessState PrivacyPolicy](modules/WebDocument/atlas/atlas-webdocument-886db8ec5f.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [04 WebDocumentSuccessState PrivacyPolicy ScrollEnd](modules/WebDocument/atlas/atlas-webdocument-a34e739ffd.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [05 WebDocumentSuccessState TermsAndConditions](modules/WebDocument/atlas/atlas-webdocument-56a59f920a.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [06 WebDocumentSuccessState TermsAndConditions ScrollEnd](modules/WebDocument/atlas/atlas-webdocument-00d5d4b4f8.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [07 WebDocumentErrorState DocumentRequestFailed](modules/WebDocument/atlas/atlas-webdocument-715cffe822.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| SelectUSExaminationType | [01 SelectUSExaminationTypeContentState FirstUse](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-913eece467.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| SelectUSExaminationType | [02 SelectUSExaminationTypeContentState FirstUse ScrollEnd](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-ce13f10ec9.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| SelectUSExaminationType | [03 SelectUSExaminationTypeContentState MaximumRecentTypes](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-4f50e5f632.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| SelectUSExaminationType | [04 SelectUSExaminationTypeContentState MaximumRecentTypes ScrollEnd](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-ce2f1e240c.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| Paywall | [01 PaywallCatalogLoadingState LoadingPlans](modules/Paywall/atlas/atlas-paywall-df58973130.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [02 PaywallCatalogLoadingState LoadingPlans ScrollEnd](modules/Paywall/atlas/atlas-paywall-6c47a7360b.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [03 PaywallCatalogErrorState PlansRequestFailed](modules/Paywall/atlas/atlas-paywall-80c9975ec0.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [04 PaywallSuccessState AvailablePlans](modules/Paywall/atlas/atlas-paywall-612fc205f2.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [05 PaywallSuccessState AvailablePlans ScrollEnd](modules/Paywall/atlas/atlas-paywall-a73174a54e.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [06 PaywallPurchaseLoadingState PurchasingOrRestoring](modules/Paywall/atlas/atlas-paywall-f9567bf334.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [07 PaywallPurchaseLoadingState PurchasingOrRestoring ScrollEnd](modules/Paywall/atlas/atlas-paywall-041133ab7f.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [08 PaywallOperationErrorState PaymentOperationFailed](modules/Paywall/atlas/atlas-paywall-6d8eea91ef.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [09 PaywallOperationErrorState PaymentOperationFailed ScrollEnd](modules/Paywall/atlas/atlas-paywall-7a1d597e59.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Scan | [01 ScanInitialState BeforeDraftRestoration](modules/Scan/atlas/atlas-scan-74dd88ee5a.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [02 ScanInitialState BeforeDraftRestoration ScrollEnd](modules/Scan/atlas/atlas-scan-b4d5307ca8.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [03 ScanInitializationErrorState DraftReadFailed](modules/Scan/atlas/atlas-scan-6d3b1d4aa3.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [04 ScanInitializationErrorState DraftReadFailed ScrollEnd](modules/Scan/atlas/atlas-scan-844d87fb52.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [05 ScanInitialState RestoredDraft](modules/Scan/atlas/atlas-scan-0551015f9a.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [06 ScanInitialState RestoredDraft ScrollEnd](modules/Scan/atlas/atlas-scan-c5b63118ec.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [07 ScanGenerationLoadingState GeneratingReport](modules/Scan/atlas/atlas-scan-53ce7b6acb.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [08 ScanGenerationLoadingState GeneratingReport ScrollEnd](modules/Scan/atlas/atlas-scan-2b52f6f794.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [09 ScanErrorState GenerationFailed](modules/Scan/atlas/atlas-scan-dd462aebe9.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [10 ScanErrorState GenerationFailed ScrollEnd](modules/Scan/atlas/atlas-scan-a1ffa711d4.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Menu | [01 MenuContentState HistoryCountAvailable](modules/Menu/atlas/atlas-menu-76d8e41335.yaml) | [Preview](../ios/Doglyad/Application/Module/Menu/Preview/MenuPreview.swift) |
| Menu | [02 MenuContentState HistoryCountAvailable ScrollEnd](modules/Menu/atlas/atlas-menu-2c9b354081.yaml) | [Preview](../ios/Doglyad/Application/Module/Menu/Preview/MenuPreview.swift) |
| Menu | [03 MenuContentState HistoryCountUnavailable](modules/Menu/atlas/atlas-menu-2858e3b34a.yaml) | [Preview](../ios/Doglyad/Application/Module/Menu/Preview/MenuPreview.swift) |
| Menu | [04 MenuContentState HistoryCountUnavailable ScrollEnd](modules/Menu/atlas/atlas-menu-fbd534a5f9.yaml) | [Preview](../ios/Doglyad/Application/Module/Menu/Preview/MenuPreview.swift) |
| Menu | [05 MenuContentState NoCompletedReports](modules/Menu/atlas/atlas-menu-6f4c5438d5.yaml) | [Preview](../ios/Doglyad/Application/Module/Menu/Preview/MenuPreview.swift) |
| Menu | [06 MenuContentState NoCompletedReports ScrollEnd](modules/Menu/atlas/atlas-menu-741bfb004e.yaml) | [Preview](../ios/Doglyad/Application/Module/Menu/Preview/MenuPreview.swift) |
| History | [01 HistoryErrorState ReportsReadFailed](modules/History/atlas/atlas-history-d97e668a24.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [02 HistoryEmptyState NoReports](modules/History/atlas/atlas-history-31d73cce69.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [03 HistoryEmptyState NoReports ScrollEnd](modules/History/atlas/atlas-history-667e9a82a6.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [04 HistoryContentState SingleReport](modules/History/atlas/atlas-history-fcc89a0cd2.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [05 HistoryContentState SingleReport ScrollEnd](modules/History/atlas/atlas-history-df0782e5e6.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [06 HistoryContentState GroupedReports](modules/History/atlas/atlas-history-6abb98e1c9.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [07 HistoryContentState GroupedReports ScrollEnd](modules/History/atlas/atlas-history-2ca79bb37a.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [08 HistoryErrorState NextPageReadFailed](modules/History/atlas/atlas-history-ceeb102ae3.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [09 HistoryErrorState NextPageReadFailed ScrollEnd](modules/History/atlas/atlas-history-a83c9e9fd5.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| ReportDetail | [01 ReportDetailContentState SavedReport](modules/ReportDetail/atlas/atlas-reportdetail-c61333b022.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [02 ReportDetailContentState SavedReport ScrollEnd](modules/ReportDetail/atlas/atlas-reportdetail-0f23a41ca5.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [03 ReportDetailGenerationLoadingState RegeneratingReport](modules/ReportDetail/atlas/atlas-reportdetail-6e9bcf94e6.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [04 ReportDetailGenerationLoadingState RegeneratingReport ScrollEnd](modules/ReportDetail/atlas/atlas-reportdetail-98ab0b5831.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [05 ReportDetailErrorState ReportOperationFailed](modules/ReportDetail/atlas/atlas-reportdetail-09507c01ab.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [06 ReportDetailErrorState ReportOperationFailed ScrollEnd](modules/ReportDetail/atlas/atlas-reportdetail-14bbea80c1.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| TemplateList | [01 TemplateListErrorState TemplatesReadFailed](modules/TemplateList/atlas/atlas-templatelist-4e05be7a19.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [02 TemplateListEmptyState NoSavedTemplates](modules/TemplateList/atlas/atlas-templatelist-f5817c91c8.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [03 TemplateListEmptyState NoSavedTemplates ScrollEnd](modules/TemplateList/atlas/atlas-templatelist-0805a2f77f.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [04 TemplateListContentState SavedTemplates](modules/TemplateList/atlas/atlas-templatelist-9696e4aa4a.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [05 TemplateListContentState SavedTemplates ScrollEnd](modules/TemplateList/atlas/atlas-templatelist-177c42e6ae.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateAdd | [01 TemplateAddInitialState EditableForm](modules/TemplateAdd/atlas/atlas-templateadd-a47a1b0e22.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| TemplateAdd | [02 TemplateAddInitialState EditableForm ScrollEnd](modules/TemplateAdd/atlas/atlas-templateadd-01de1cd06c.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| TemplateAdd | [03 TemplateAddErrorState TemplateSaveFailed](modules/TemplateAdd/atlas/atlas-templateadd-35a1bb21d0.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| TemplateAdd | [04 TemplateAddErrorState TemplateSaveFailed ScrollEnd](modules/TemplateAdd/atlas/atlas-templateadd-63a1380977.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| ReadyMadeTemplateList | [01 ReadyMadeTemplateListLoadingState LoadingCatalog](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-e3f98c4ed3.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [02 ReadyMadeTemplateListLoadingState LoadingCatalog ScrollEnd](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-ee8bbca2a5.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [03 ReadyMadeTemplateListErrorState CatalogRequestFailed](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-0470db9ae8.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [04 ReadyMadeTemplateListSuccessState EmptyCatalog](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-be8e44484b.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [05 ReadyMadeTemplateListSuccessState AvailableTemplates](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-0bc4b7e67d.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [06 ReadyMadeTemplateListSuccessState AvailableTemplates ScrollEnd](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-cc4be80179.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| TemplateEdit | [01 TemplateEditInitializationErrorState TemplateReadFailed](modules/TemplateEdit/atlas/atlas-templateedit-b84805e747.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [02 TemplateEditInitializationErrorState TemplateReadFailed ScrollEnd](modules/TemplateEdit/atlas/atlas-templateedit-ca3b4007e6.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [03 TemplateEditInitialState EditableTemplate](modules/TemplateEdit/atlas/atlas-templateedit-ed265d6473.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [04 TemplateEditInitialState EditableTemplate ScrollEnd](modules/TemplateEdit/atlas/atlas-templateedit-6f0325c227.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [05 TemplateEditErrorState TemplateOperationFailed](modules/TemplateEdit/atlas/atlas-templateedit-01a51ac046.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [06 TemplateEditErrorState TemplateOperationFailed ScrollEnd](modules/TemplateEdit/atlas/atlas-templateedit-db36b1960e.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateDelete | [01 TemplateDeleteDefaultState ConfirmDeletion](modules/TemplateDelete/atlas/atlas-templatedelete-15c7b1ef45.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TempalteDelete/Preview/TemplateDeletePreview.swift) |
| WorkSettings | [01 WorkSettingsInitialState WorkPreferences](modules/WorkSettings/atlas/atlas-worksettings-c6fac5aeb8.yaml) | [Preview](../ios/Doglyad/Application/Module/WorkSettings/Preview/WorkSettingsPreview.swift) |
| WorkSettings | [02 WorkSettingsInitialState WorkPreferences ScrollEnd](modules/WorkSettings/atlas/atlas-worksettings-e718ace8f4.yaml) | [Preview](../ios/Doglyad/Application/Module/WorkSettings/Preview/WorkSettingsPreview.swift) |
| WorkSettings | [03 WorkSettingsInitialState PatientConsentDisabled](modules/WorkSettings/atlas/atlas-worksettings-b6ae9979bc.yaml) | [Preview](../ios/Doglyad/Application/Module/WorkSettings/Preview/WorkSettingsPreview.swift) |
| WorkSettings | [04 WorkSettingsInitialState PatientConsentDisabled ScrollEnd](modules/WorkSettings/atlas/atlas-worksettings-a27c17f5ce.yaml) | [Preview](../ios/Doglyad/Application/Module/WorkSettings/Preview/WorkSettingsPreview.swift) |
| WorkSettings | [05 WorkSettingsErrorState PreferencesSaveFailed](modules/WorkSettings/atlas/atlas-worksettings-17a6512eb4.yaml) | [Preview](../ios/Doglyad/Application/Module/WorkSettings/Preview/WorkSettingsPreview.swift) |
| WorkSettings | [06 WorkSettingsErrorState PreferencesSaveFailed ScrollEnd](modules/WorkSettings/atlas/atlas-worksettings-ebdef23f53.yaml) | [Preview](../ios/Doglyad/Application/Module/WorkSettings/Preview/WorkSettingsPreview.swift) |
| SettingsAI | [01 SettingsAIInitialState CurrentPreferences](modules/SettingsAI/atlas/atlas-settingsai-f46a59b1b3.yaml) | [Preview](../ios/Doglyad/Application/Module/SettingsAI/Preview/SettingsAIPreview.swift) |
| SettingsAI | [02 SettingsAIInitialState CurrentPreferences ScrollEnd](modules/SettingsAI/atlas/atlas-settingsai-b7209852fc.yaml) | [Preview](../ios/Doglyad/Application/Module/SettingsAI/Preview/SettingsAIPreview.swift) |
| SettingsAI | [03 SettingsAIErrorState PreferencesSaveFailed](modules/SettingsAI/atlas/atlas-settingsai-e993ef39f9.yaml) | [Preview](../ios/Doglyad/Application/Module/SettingsAI/Preview/SettingsAIPreview.swift) |
| SettingsAI | [04 SettingsAIErrorState PreferencesSaveFailed ScrollEnd](modules/SettingsAI/atlas/atlas-settingsai-9e6402ea61.yaml) | [Preview](../ios/Doglyad/Application/Module/SettingsAI/Preview/SettingsAIPreview.swift) |
| SelectTranscriber | [01 SelectTranscriberInitialState AvailableTranscribers](modules/SelectTranscriber/atlas/atlas-selecttranscriber-af860819bc.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTranscriber/Preview/SelectTranscriberPreview.swift) |
| SelectTranscriber | [02 SelectTranscriberInitialState AvailableTranscribers ScrollEnd](modules/SelectTranscriber/atlas/atlas-selecttranscriber-f305449c4b.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTranscriber/Preview/SelectTranscriberPreview.swift) |
| SelectTranscriptParser | [01 SelectTranscriptParserDefaultState AvailableParsers](modules/SelectTranscriptParser/atlas/atlas-selecttranscriptparser-6a2d3a4672.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTranscriptParser/Preview/SelectTranscriptParserPreview.swift) |
| SelectTranscriptParser | [02 SelectTranscriptParserDefaultState AvailableParsers ScrollEnd](modules/SelectTranscriptParser/atlas/atlas-selecttranscriptparser-712d83f904.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTranscriptParser/Preview/SelectTranscriptParserPreview.swift) |
| SelectNeuralModel | [01 SelectNeuralModelInitialState AvailableModels](modules/SelectNeuralModel/atlas/atlas-selectneuralmodel-5727c268ce.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectNeuralModel/Preview/SelectNeuralModelPreview.swift) |
| SelectNeuralModel | [02 SelectNeuralModelInitialState AvailableModels ScrollEnd](modules/SelectNeuralModel/atlas/atlas-selectneuralmodel-ffb53d6122.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectNeuralModel/Preview/SelectNeuralModelPreview.swift) |
| ManageSubscription | [01 ManageSubscriptionCatalogLoadingState LoadingCatalog](modules/ManageSubscription/atlas/atlas-managesubscription-673089ff33.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [02 ManageSubscriptionCatalogLoadingState LoadingCatalog ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-da5816cab4.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [03 ManageSubscriptionErrorState CatalogRequestFailed](modules/ManageSubscription/atlas/atlas-managesubscription-890ec5c127.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [04 ManageSubscriptionSuccessState NoSubscription](modules/ManageSubscription/atlas/atlas-managesubscription-47c3865bd5.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [05 ManageSubscriptionSuccessState NoSubscription ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-0d113db030.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [06 ManageSubscriptionSuccessState AppleBase](modules/ManageSubscription/atlas/atlas-managesubscription-db770b64b8.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [07 ManageSubscriptionSuccessState AppleBase ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-2e59d64a9a.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [08 ManageSubscriptionSuccessState YooKassaBase](modules/ManageSubscription/atlas/atlas-managesubscription-84ce68035b.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [09 ManageSubscriptionSuccessState YooKassaBase ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-f07fbd2c88.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [10 ManageSubscriptionSuccessState ApplePro](modules/ManageSubscription/atlas/atlas-managesubscription-3ae9771b32.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [11 ManageSubscriptionSuccessState ApplePro ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-8da24afd04.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [12 ManageSubscriptionSuccessState YooKassaPro](modules/ManageSubscription/atlas/atlas-managesubscription-d8d0000386.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [13 ManageSubscriptionSuccessState YooKassaPro ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-73a48fc631.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [14 ManageSubscriptionRefreshLoadingState RefreshingSubscription](modules/ManageSubscription/atlas/atlas-managesubscription-60db48ce0a.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [15 ManageSubscriptionRefreshLoadingState RefreshingSubscription ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-f23ba334c7.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [16 ManageSubscriptionSuccessState AppleRenewalDisabled](modules/ManageSubscription/atlas/atlas-managesubscription-ad7bc6de1e.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [17 ManageSubscriptionSuccessState AppleRenewalDisabled ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-5272edbfdb.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [18 ManageSubscriptionSuccessState YooKassaRenewalDisabled](modules/ManageSubscription/atlas/atlas-managesubscription-dd9eea1ae7.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [19 ManageSubscriptionSuccessState YooKassaRenewalDisabled ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-36dbf90817.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [20 ManageSubscriptionErrorState OperationFailed](modules/ManageSubscription/atlas/atlas-managesubscription-b006dfaa0b.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [21 ManageSubscriptionErrorState OperationFailed ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-a72932f295.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [22 ManageSubscriptionRestoreLoadingState RestoringPurchases](modules/ManageSubscription/atlas/atlas-managesubscription-4af13fa1b2.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [23 ManageSubscriptionRestoreLoadingState RestoringPurchases ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-1e3eb53fc5.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [24 ManageSubscriptionManagementLoadingState ManagingRenewal](modules/ManageSubscription/atlas/atlas-managesubscription-83487d7851.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [25 ManageSubscriptionManagementLoadingState ManagingRenewal ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-e9631fccd7.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [26 ManageSubscriptionRefundLoadingState RequestingRefund](modules/ManageSubscription/atlas/atlas-managesubscription-46ad7017fd.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [27 ManageSubscriptionRefundLoadingState RequestingRefund ScrollEnd](modules/ManageSubscription/atlas/atlas-managesubscription-9913a424d2.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| SubscriptionRecovery | [01 SubscriptionRecoveryInitialState NoRecoveryKey](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-5cf3ae726e.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [02 SubscriptionRecoveryInitialState NoRecoveryKey ScrollEnd](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-a0ef1134d3.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [03 SubscriptionRecoveryKeyCreationLoadingState CreatingRecoveryKey](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-095c9da4e1.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [04 SubscriptionRecoveryKeyCreationLoadingState CreatingRecoveryKey ScrollEnd](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-56bffe9075.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [05 SubscriptionRecoverySuccessState RecoveryKeyCreated](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-51f360d0ea.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [06 SubscriptionRecoverySuccessState RecoveryKeyCreated ScrollEnd](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-07c3664d36.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [07 SubscriptionRecoveryRestoreLoadingState RestoringWithKey](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-148a1398c1.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [08 SubscriptionRecoveryRestoreLoadingState RestoringWithKey ScrollEnd](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-f82dc575be.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [09 SubscriptionRecoveryErrorState RecoveryFailedWithoutKey](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-1328a24cbb.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [10 SubscriptionRecoveryErrorState RecoveryFailedWithoutKey ScrollEnd](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-b41e4a20af.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [11 SubscriptionRecoveryErrorState RecoveryFailedWithRetainedKey](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-701281a3a4.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [12 SubscriptionRecoveryErrorState RecoveryFailedWithRetainedKey ScrollEnd](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-fdaaeb6d33.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| Storage | [01 StorageInitialState StoredData](modules/Storage/atlas/atlas-storage-769a608ea9.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [02 StorageInitialState StoredData ScrollEnd](modules/Storage/atlas/atlas-storage-41ea620f8e.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [03 StorageInitialState SpeechModelNotDownloaded](modules/Storage/atlas/atlas-storage-ce39a4e477.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [04 StorageInitialState SpeechModelNotDownloaded ScrollEnd](modules/Storage/atlas/atlas-storage-9ba8134a25.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [05 StorageErrorState ClearOperationFailed](modules/Storage/atlas/atlas-storage-bdca658ce0.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [06 StorageErrorState ClearOperationFailed ScrollEnd](modules/Storage/atlas/atlas-storage-cd219b651c.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| StorageClearProtocols | [01 StorageClearProtocolsDefaultState ConfirmDeletion](modules/StorageClearProtocols/atlas/atlas-storageclearprotocols-bb85780d0a.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/StorageClearProtocols/Preview/StorageClearProtocolsPreview.swift) |
| StorageClearSpeechModel | [01 StorageClearSpeechModelDefaultState ConfirmModelDeletion](modules/StorageClearSpeechModel/atlas/atlas-storageclearspeechmodel-09b7f0db3a.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/StorageClearSpeechModel/Preview/StorageClearSpeechModelPreview.swift) |
| StorageClearAll | [01 StorageClearAllDefaultState ConfirmDeletion](modules/StorageClearAll/atlas/atlas-storageclearall-95d9776313.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/StorageClearAll/Preview/StorageClearAllPreview.swift) |
| About | [01 AboutDefaultState ApplicationInformation](modules/About/atlas/atlas-about-34aa3c32a4.yaml) | [Preview](../ios/Doglyad/Application/Module/About/Preview/AboutPreview.swift) |
| SelectDateOfBirth | [01 SelectDateOfBirthDefaultState DateSelection](modules/SelectDateOfBirth/atlas/atlas-selectdateofbirth-da060cd631.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectDateOfBirth/Preview/SelectDateOfBirthPreview.swift) |
| SelectTemplate | [01 SelectTemplateContentState SavedTemplates](modules/SelectTemplate/atlas/atlas-selecttemplate-165e391871.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| SelectTemplate | [02 SelectTemplateContentState SavedTemplates ScrollEnd](modules/SelectTemplate/atlas/atlas-selecttemplate-edd39786e4.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| ImportMedia | [01 ImportMediaDefaultState MediaSources](modules/ImportMedia/atlas/atlas-importmedia-47b155b637.yaml) | [Preview](../ios/Doglyad/Application/Module/ImportMedia/Preview/ImportMediaPreview.swift) |
| Permission | [01 PermissionDefaultState CameraAccess](modules/Permission/atlas/atlas-permission-e183ab458d.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Preview/PermissionPreview.swift) |
| Permission | [02 PermissionDefaultState MicrophoneAccess](modules/Permission/atlas/atlas-permission-d792958d46.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Preview/PermissionPreview.swift) |
| Permission | [03 PermissionDefaultState PhotoLibraryAccess](modules/Permission/atlas/atlas-permission-411c377fa4.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Preview/PermissionPreview.swift) |
| ScanCamera | [01 ScanCameraPreparationLoadingState PreparingCamera](modules/ScanCamera/atlas/atlas-scancamera-c90f175fbd.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [02 ScanCameraReadyState CameraReady](modules/ScanCamera/atlas/atlas-scancamera-2683f90c0e.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [03 ScanCameraCaptureLoadingState CapturingPhoto](modules/ScanCamera/atlas/atlas-scancamera-7e31b17514.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [04 ScanCameraStoppedState CameraStopped](modules/ScanCamera/atlas/atlas-scancamera-e4acb2c422.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [05 ScanCameraReadyState MultiplePhotos](modules/ScanCamera/atlas/atlas-scancamera-249de3119f.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [06 ScanCameraReadyState PhotoLimitReached](modules/ScanCamera/atlas/atlas-scancamera-c247afc03d.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| PhotoLibraryPicker | [01 PhotoLibraryPickerDefaultState PhotoLibrary](modules/PhotoLibraryPicker/atlas/atlas-photolibrarypicker-f2f3f1c67e.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Library/Preview/PhotoLibraryPickerPreview.swift) |
| PhotoView | [01 PhotoViewInitialState LandscapePhoto](modules/PhotoView/atlas/atlas-photoview-cb83f9199a.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [02 PhotoViewInitialState ModelRemarks](modules/PhotoView/atlas/atlas-photoview-9579119a99.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [03 PhotoViewInitialState SavedReportReadOnly](modules/PhotoView/atlas/atlas-photoview-1d5c0d1e99.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [04 PhotoViewInitialState PortraitPhoto](modules/PhotoView/atlas/atlas-photoview-dbe28d404c.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [05 PhotoViewInitialState SquarePhoto](modules/PhotoView/atlas/atlas-photoview-93d5132ed4.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoRemark | [01 PhotoRemarkDefaultState ModelRemark](modules/PhotoRemark/atlas/atlas-photoremark-4943bdd959.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoRemark/Preview/PhotoRemarkPreview.swift) |
| ScanSpeech | [01 ScanSpeechModelLoadingState CheckingModel](modules/ScanSpeech/atlas/atlas-scanspeech-eea0584217.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [02 ScanSpeechModelLoadingState DownloadingWithoutProgress](modules/ScanSpeech/atlas/atlas-scanspeech-c057cb4edf.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [03 ScanSpeechModelLoadingState DownloadingWithProgress](modules/ScanSpeech/atlas/atlas-scanspeech-fad7886b0f.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [04 ScanSpeechModelLoadingState LoadingModelIntoMemory](modules/ScanSpeech/atlas/atlas-scanspeech-9b5a7f0cd6.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [05 ScanSpeechModelPreparationErrorState ModelPreparationFailed](modules/ScanSpeech/atlas/atlas-scanspeech-ba10d2531c.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [06 ScanSpeechReadyState ReadyToRecord](modules/ScanSpeech/atlas/atlas-scanspeech-92fb22e583.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [07 ScanSpeechRecordingPreparationLoadingState PreparingRecording](modules/ScanSpeech/atlas/atlas-scanspeech-afd5c37eab.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [08 ScanSpeechRecordingState RecordingSpeech](modules/ScanSpeech/atlas/atlas-scanspeech-3a8fdfca87.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [09 ScanSpeechTranscriptionLoadingState TranscribingSpeech](modules/ScanSpeech/atlas/atlas-scanspeech-ab81375794.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [10 ScanSpeechReviewTranscriptState TranscriptReview](modules/ScanSpeech/atlas/atlas-scanspeech-e014a6519e.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [11 ScanSpeechReviewTranscriptState TranscriptReview ScrollEnd](modules/ScanSpeech/atlas/atlas-scanspeech-9bedcb0d75.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [12 ScanSpeechReviewParsingLoadingState ParsingReviewedTranscript](modules/ScanSpeech/atlas/atlas-scanspeech-d10bd1f816.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [13 ScanSpeechReviewParsingLoadingState ParsingReviewedTranscript ScrollEnd](modules/ScanSpeech/atlas/atlas-scanspeech-9e9a530152.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [14 ScanSpeechReviewProposalState MultipleFields](modules/ScanSpeech/atlas/atlas-scanspeech-0b84d79e8e.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [15 ScanSpeechReviewProposalState MultipleFields ScrollEnd](modules/ScanSpeech/atlas/atlas-scanspeech-65a5940d07.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| PatientConsent | [01 PatientConsentInitialState RequestConsent](modules/PatientConsent/atlas/atlas-patientconsent-65ab0d7fc4.yaml) | [Preview](../ios/Doglyad/Application/Module/PatientConsent/Preview/PatientConsentPreview.swift) |
| PatientConsent | [02 PatientConsentInitialState DoNotAskAgainSelected](modules/PatientConsent/atlas/atlas-patientconsent-1e3a9361b8.yaml) | [Preview](../ios/Doglyad/Application/Module/PatientConsent/Preview/PatientConsentPreview.swift) |
| PatientConsent | [03 PatientConsentInitialState PreferenceSaveFailed](modules/PatientConsent/atlas/atlas-patientconsent-578517b21f.yaml) | [Preview](../ios/Doglyad/Application/Module/PatientConsent/Preview/PatientConsentPreview.swift) |
| ReportReceived | [01 ReportReceivedContentState WaitingForFirstToken](modules/ReportReceived/atlas/atlas-reportreceived-b3cfe90b8d.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [02 ReportReceivedContentState WaitingForFirstToken ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-6341165098.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [03 ReportReceivedContentState FirstToken](modules/ReportReceived/atlas/atlas-reportreceived-dc2bbae3d7.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [04 ReportReceivedContentState FirstToken ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-6ae420661f.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [05 ReportReceivedContentState StreamingDescription](modules/ReportReceived/atlas/atlas-reportreceived-8b4b8be0ce.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [06 ReportReceivedContentState StreamingDescription ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-7eaca60f66.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [07 ReportReceivedContentState StreamingConclusion](modules/ReportReceived/atlas/atlas-reportreceived-4754d3b315.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [08 ReportReceivedContentState StreamingConclusion ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-0796d42cf6.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [09 ReportReceivedContentState CompletedReport](modules/ReportReceived/atlas/atlas-reportreceived-cdcf1b6cc4.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [10 ReportReceivedContentState CompletedReport ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-54c562ac9e.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [11 ReportReceivedContentState CompletedWithRemarks](modules/ReportReceived/atlas/atlas-reportreceived-dd656c6ec4.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [12 ReportReceivedContentState CompletedWithRemarks ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-6df7685139.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [13 ReportReceivedContentState OpenedFromReportDetail](modules/ReportReceived/atlas/atlas-reportreceived-268fc0b805.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [14 ReportReceivedContentState OpenedFromReportDetail ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-96519e7311.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [15 ReportReceivedContentState NoWorkEmail](modules/ReportReceived/atlas/atlas-reportreceived-f4e6fa0577.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [16 ReportReceivedContentState NoWorkEmail ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-d14639a3b9.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [17 ReportReceivedContentState EmailRequiresPro](modules/ReportReceived/atlas/atlas-reportreceived-9f6fa5a70f.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [18 ReportReceivedContentState EmailRequiresPro ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-a7a541e623.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [19 ReportReceivedContentState EmailUnavailable](modules/ReportReceived/atlas/atlas-reportreceived-3d3273a809.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [20 ReportReceivedContentState EmailUnavailable ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-78014bec35.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [21 ReportReceivedLoadingState SendingEmail](modules/ReportReceived/atlas/atlas-reportreceived-73e6563b25.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [22 ReportReceivedLoadingState SendingEmail ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-b38ac3a6f3.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [23 ReportReceivedDeliveryErrorState EmailDeliveryFailed](modules/ReportReceived/atlas/atlas-reportreceived-a93c9f4a3c.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [24 ReportReceivedDeliveryErrorState EmailDeliveryFailed ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-4e457c9abf.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [25 ReportReceivedContentState InterruptedWithoutText](modules/ReportReceived/atlas/atlas-reportreceived-ea06f3e1fa.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [26 ReportReceivedContentState InterruptedWithoutText ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-e1655f8b80.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [27 ReportReceivedContentState InterruptedWithPartialText](modules/ReportReceived/atlas/atlas-reportreceived-f5b346407b.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [28 ReportReceivedContentState InterruptedWithPartialText ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-3815e3e3db.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [29 ReportReceivedContentState GenerationFailedWithoutText](modules/ReportReceived/atlas/atlas-reportreceived-358a7b5f62.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [30 ReportReceivedContentState GenerationFailedWithoutText ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-e324c8204e.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [31 ReportReceivedContentState GenerationFailedWithPartialText](modules/ReportReceived/atlas/atlas-reportreceived-4665d336b0.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [32 ReportReceivedContentState GenerationFailedWithPartialText ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-99ed31c48b.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [33 ReportReceivedContentState GenerationCancelled](modules/ReportReceived/atlas/atlas-reportreceived-98d23f5ffc.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [34 ReportReceivedContentState GenerationCancelled ScrollEnd](modules/ReportReceived/atlas/atlas-reportreceived-a02f6564e6.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| Share | [01 ShareInitialState AvailableActions](modules/Share/atlas/atlas-share-09ff44c3bb.yaml) | [Preview](../ios/Doglyad/Application/Module/Share/Preview/SharePreview.swift) |
| Share | [02 ShareLoadingState PreparingDocument](modules/Share/atlas/atlas-share-bb9f8b8182.yaml) | [Preview](../ios/Doglyad/Application/Module/Share/Preview/SharePreview.swift) |
| Share | [03 ShareErrorState DocumentPreparationFailed](modules/Share/atlas/atlas-share-17db79c860.yaml) | [Preview](../ios/Doglyad/Application/Module/Share/Preview/SharePreview.swift) |
| RequestLimitExceeded | [01 RequestLimitExceededDefaultState DailyLimitReached](modules/RequestLimitExceeded/atlas/atlas-requestlimitexceeded-741f51e813.yaml) | [Preview](../ios/Doglyad/Application/Module/LimitExceeded/Preview/RequestLimitExceededPreview.swift) |
