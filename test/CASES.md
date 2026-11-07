# Регресс-кейсы

Описание сценариев каждого модуля и статус автоматизации: [COVERAGE.md](COVERAGE.md). Ниже перечислены исполняемые flows и отдельные Preview-снимки.

Список создаёт `python3 test/scripts/catalog.py`. Это перечень проверок, а не результат запуска.

Платформа: iOS. Модулей: 39. Функциональных кейсов с вводным сценарием: 129. Кейсов отображения: 154.

## Функциональные сценарии

Выполняются в указанном порядке на новом стенде. YAML содержит шаги и ожидаемый результат.

| Кейс | Проверка | Снимков |
|---|---|---|
| [bootstrap-onboarding](modules/OnBoarding/e2e/bootstrap.yaml) | Первый запуск: onboarding, согласие, выбор исследования и paywall | 7 |
| [e2e-history-history-empty](modules/History/e2e/history-empty.yaml) | История пуста на новом стенде | 1 |
| [e2e-reportreceived-generation](modules/ReportReceived/e2e/generation.yaml) | Сгенерировать и открыть протокол через локальный backend | 2 |
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
| [e2e-settings-history-summary-retry](modules/Settings/e2e/history-summary-retry.yaml) | Ошибка счётчика истории и повтор загрузки | 2 |
| [e2e-settings-navigation](modules/Settings/e2e/navigation.yaml) | Все пункты настроек в порядке экрана и возврат без изменений | 2 |
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
| [e2e-usersettings-work-settings](modules/UserSettings/e2e/work-settings.yaml) | Рабочий email сохраняется после перезапуска | 1 |
| [e2e-usersettings-flags-000](modules/UserSettings/e2e/flags-000.yaml) | Переключатели: 000 сохраняются после перезапуска | 2 |
| [e2e-usersettings-flags-001](modules/UserSettings/e2e/flags-001.yaml) | Переключатели: 001 сохраняются после перезапуска | 2 |
| [e2e-usersettings-flags-010](modules/UserSettings/e2e/flags-010.yaml) | Переключатели: 010 сохраняются после перезапуска | 2 |
| [e2e-usersettings-flags-011](modules/UserSettings/e2e/flags-011.yaml) | Переключатели: 011 сохраняются после перезапуска | 2 |
| [e2e-usersettings-flags-100](modules/UserSettings/e2e/flags-100.yaml) | Переключатели: 100 сохраняются после перезапуска | 2 |
| [e2e-usersettings-flags-101](modules/UserSettings/e2e/flags-101.yaml) | Переключатели: 101 сохраняются после перезапуска | 2 |
| [e2e-usersettings-flags-110](modules/UserSettings/e2e/flags-110.yaml) | Переключатели: 110 сохраняются после перезапуска | 2 |
| [e2e-usersettings-flags-111](modules/UserSettings/e2e/flags-111.yaml) | Переключатели: 111 сохраняются после перезапуска | 2 |
| [e2e-usersettings-invalid-email](modules/UserSettings/e2e/invalid-email.yaml) | Неверная почта не заменяет сохранённую | 1 |
| [e2e-usersettings-save-failure](modules/UserSettings/e2e/save-failure.yaml) | Отмена правки почты, ошибка записи и повтор | 2 |
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
| [e2e-storage-delete-speech-model](modules/Storage/e2e/delete-speech-model.yaml) | Удаление локальной речевой модели и повторная подготовка | 3 |
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

## Отображение состояний модулей

Каждый кейс запускает существующий preview модуля, проверяет его идентификатор и делает снимок.
Эти кейсы не проверяют переходы в состояния или работу внешних интеграций. Ограничения описаны в [README](README.md#покрытие-и-ограничения).

| Модуль | Состояние и YAML | Исходник |
|---|---|---|
| ApplicationSplash | [01 ApplicationSplash](modules/ApplicationSplash/atlas/atlas-applicationsplash-686139405c.yaml) | [Preview](../ios/Doglyad/Application/Application/Application/Preview/ApplicationSplashPreview.swift) |
| OnBoarding | [01 OnBoardingFirstState](modules/OnBoarding/atlas/atlas-onboarding-d9d62fc1e3.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [02 OnBoardingSecondState](modules/OnBoarding/atlas/atlas-onboarding-22931274f9.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [03 OnBoardingLegalState](modules/OnBoarding/atlas/atlas-onboarding-64023d86bc.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [04 Согласие принято](modules/OnBoarding/atlas/atlas-onboarding-6491f10c7e.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [05 OnBoardingExaminationTypeState](modules/OnBoarding/atlas/atlas-onboarding-393cd796b5.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [06 OnBoardingFinalState](modules/OnBoarding/atlas/atlas-onboarding-827b47baa8.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [07 OnBoardingCompletingState](modules/OnBoarding/atlas/atlas-onboarding-e0feec1a6e.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [08 OnBoardingFailedState](modules/OnBoarding/atlas/atlas-onboarding-660276f3c0.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| WebDocument | [01 WebDocumentLoadingState](modules/WebDocument/atlas/atlas-webdocument-74aa813450.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [02 WebDocumentLoadedState](modules/WebDocument/atlas/atlas-webdocument-0c11461a57.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [03 WebDocumentFailedState](modules/WebDocument/atlas/atlas-webdocument-8b51e76f05.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| SelectUSExaminationType | [01 SelectUSExaminationTypeLoadingState](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-d7d1e43cbe.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| SelectUSExaminationType | [02 SelectUSExaminationTypeFailedState](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-b3093417e8.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| SelectUSExaminationType | [03 SelectUSExaminationTypeContentState](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-966f691d4f.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| SelectUSExaminationType | [04 SelectUSExaminationTypeSelectingState](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-ccc0fffcbe.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| Paywall | [01 PaywallLoadingState](modules/Paywall/atlas/atlas-paywall-156b703e99.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [02 PaywallLoadingFailedState](modules/Paywall/atlas/atlas-paywall-ae8aab4ea7.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [03 PaywallDefaultState](modules/Paywall/atlas/atlas-paywall-d681dd4b3b.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [04 Русский](modules/Paywall/atlas/atlas-paywall-6da140fdd4.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [05 Каталог без предложений](modules/Paywall/atlas/atlas-paywall-5687a8e2b0.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [06 Обновление тарифов](modules/Paywall/atlas/atlas-paywall-5b7e4afd88.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [07 PaywallPurchasingState](modules/Paywall/atlas/atlas-paywall-56dbd6283c.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [08 PaywallPendingState](modules/Paywall/atlas/atlas-paywall-93c932ac6f.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [09 PaywallOperationFailedState](modules/Paywall/atlas/atlas-paywall-6e1176fbf4.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [10 PaywallRestoringState](modules/Paywall/atlas/atlas-paywall-5061371ef7.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [11 Восстановление без каталога](modules/Paywall/atlas/atlas-paywall-9567bc35b4.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Scan | [01 ScanInitializingState](modules/Scan/atlas/atlas-scan-fcfbf6227f.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [02 ScanInitializationFailedState](modules/Scan/atlas/atlas-scan-eaa41d57a9.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [03 ScanDefaultState](modules/Scan/atlas/atlas-scan-b902f0dd58.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [04 ScanGeneratingState](modules/Scan/atlas/atlas-scan-6d7db7f8f8.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [05 ScanLoadingState](modules/Scan/atlas/atlas-scan-828ea2d5eb.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [06 ScanClearingState](modules/Scan/atlas/atlas-scan-511dd131cc.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [07 ScanFailedState](modules/Scan/atlas/atlas-scan-6307577c52.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Settings | [01 SettingsLoadingState](modules/Settings/atlas/atlas-settings-32ad4fc9be.yaml) | [Preview](../ios/Doglyad/Application/Module/Settings/Settings/Preview/SettingsPreview.swift) |
| Settings | [02 SettingsFailedState](modules/Settings/atlas/atlas-settings-b5c02a3d31.yaml) | [Preview](../ios/Doglyad/Application/Module/Settings/Settings/Preview/SettingsPreview.swift) |
| Settings | [03 SettingsContentState](modules/Settings/atlas/atlas-settings-c86c0ece67.yaml) | [Preview](../ios/Doglyad/Application/Module/Settings/Settings/Preview/SettingsPreview.swift) |
| History | [01 Загрузка истории](modules/History/atlas/atlas-history-37383d76bb.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [02 Ошибка загрузки истории](modules/History/atlas/atlas-history-8aec803b84.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [03 Пустая история](modules/History/atlas/atlas-history-1152fbb8a1.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [04 Одно исследование](modules/History/atlas/atlas-history-d9be5b3215.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [05 История · группы дат и разные протоколы](modules/History/atlas/atlas-history-f6362aeb89.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [06 Загрузка следующей страницы](modules/History/atlas/atlas-history-59976b934b.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| History | [07 Ошибка следующей страницы](modules/History/atlas/atlas-history-89033663fd.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| ReportDetail | [01 ReportDetailContentState](modules/ReportDetail/atlas/atlas-reportdetail-3c375c3930.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [02 ReportDetailLoadingState](modules/ReportDetail/atlas/atlas-reportdetail-0e4adde340.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [03 ReportDetailGeneratingState](modules/ReportDetail/atlas/atlas-reportdetail-9ecf859368.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [04 ReportDetailFailedState](modules/ReportDetail/atlas/atlas-reportdetail-eb8db8a872.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| TemplateList | [01 TemplateListLoadingState](modules/TemplateList/atlas/atlas-templatelist-ae8997d3b5.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [02 TemplateListFailedState](modules/TemplateList/atlas/atlas-templatelist-03855e8c3f.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [03 TemplateListEmptyState](modules/TemplateList/atlas/atlas-templatelist-1f8dfe97cf.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [04 TemplateListContentState](modules/TemplateList/atlas/atlas-templatelist-84499cf1eb.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateAdd | [01 TemplateAddLoadingState](modules/TemplateAdd/atlas/atlas-templateadd-d6cf7578d7.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| TemplateAdd | [02 TemplateAddDefaultState](modules/TemplateAdd/atlas/atlas-templateadd-d732216ec4.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| TemplateAdd | [03 TemplateAddFailedState](modules/TemplateAdd/atlas/atlas-templateadd-780cf44421.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| ReadyMadeTemplateList | [01 ReadyMadeTemplateListLoadingState](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-b2303cf106.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [02 ReadyMadeTemplateListFailedState](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-579ef5fc0d.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [03 Каталог пуст](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-6db21dc344.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [04 ReadyMadeTemplateListContentState](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-36a13cb7d8.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| TemplateEdit | [01 TemplateEditLoadingState](modules/TemplateEdit/atlas/atlas-templateedit-7370b58af0.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [02 TemplateEditInitializationFailedState](modules/TemplateEdit/atlas/atlas-templateedit-e453ba653b.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [03 TemplateEditDefaultState](modules/TemplateEdit/atlas/atlas-templateedit-16e73e44db.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [04 TemplateEditFailedState](modules/TemplateEdit/atlas/atlas-templateedit-ddace9f930.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateDelete | [01 TemplateDeleteState](modules/TemplateDelete/atlas/atlas-templatedelete-bfb2715107.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TempalteDelete/Preview/TemplateDeletePreview.swift) |
| UserSettings | [01 UserSettingsDefaultState](modules/UserSettings/atlas/atlas-usersettings-0fd932d31b.yaml) | [Preview](../ios/Doglyad/Application/Module/UserSettings/Preview/UserSettingsPreview.swift) |
| UserSettings | [02 UserSettingsLoadingState](modules/UserSettings/atlas/atlas-usersettings-0a6fe5a8ec.yaml) | [Preview](../ios/Doglyad/Application/Module/UserSettings/Preview/UserSettingsPreview.swift) |
| UserSettings | [03 UserSettingsFailedState](modules/UserSettings/atlas/atlas-usersettings-60c11651e6.yaml) | [Preview](../ios/Doglyad/Application/Module/UserSettings/Preview/UserSettingsPreview.swift) |
| SettingsAI | [01 SettingsAIDefaultState](modules/SettingsAI/atlas/atlas-settingsai-225f1c3b13.yaml) | [Preview](../ios/Doglyad/Application/Module/Settings/SettingsAI/Preview/SettingsAIPreview.swift) |
| SettingsAI | [02 SettingsAILoadingState](modules/SettingsAI/atlas/atlas-settingsai-a8c8bdedf3.yaml) | [Preview](../ios/Doglyad/Application/Module/Settings/SettingsAI/Preview/SettingsAIPreview.swift) |
| SettingsAI | [03 SettingsAIFailedState](modules/SettingsAI/atlas/atlas-settingsai-1c1e50d046.yaml) | [Preview](../ios/Doglyad/Application/Module/Settings/SettingsAI/Preview/SettingsAIPreview.swift) |
| SelectTranscriber | [01 SelectTranscriberState](modules/SelectTranscriber/atlas/atlas-selecttranscriber-ad445bc911.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTranscriber/Preview/SelectTranscriberPreview.swift) |
| SelectTranscriptParser | [01 SelectTranscriptParserState](modules/SelectTranscriptParser/atlas/atlas-selecttranscriptparser-155ac575dd.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTranscriptParser/Preview/SelectTranscriptParserPreview.swift) |
| SelectNeuralModel | [01 SelectNeuralModelContentState](modules/SelectNeuralModel/atlas/atlas-selectneuralmodel-b5c8080bb6.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectNeuralModel/Preview/SelectNeuralModelPreview.swift) |
| SelectNeuralModel | [02 SelectNeuralModelSelectingState](modules/SelectNeuralModel/atlas/atlas-selectneuralmodel-129d16a080.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectNeuralModel/Preview/SelectNeuralModelPreview.swift) |
| ManageSubscription | [01 Загрузка](modules/ManageSubscription/atlas/atlas-managesubscription-111213e773.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [02 Ошибка загрузки](modules/ManageSubscription/atlas/atlas-managesubscription-bd54852c08.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [03 Без подписки](modules/ManageSubscription/atlas/atlas-managesubscription-2394bc4a3e.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [04 Base · App Store](modules/ManageSubscription/atlas/atlas-managesubscription-1ca567dfee.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [05 Base · ЮКасса](modules/ManageSubscription/atlas/atlas-managesubscription-7ad7a1216a.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [06 Pro · App Store](modules/ManageSubscription/atlas/atlas-managesubscription-2b5ed362bd.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [07 Pro · ЮКасса](modules/ManageSubscription/atlas/atlas-managesubscription-90e8e1ca62.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [08 Обновление подписки](modules/ManageSubscription/atlas/atlas-managesubscription-b1b8ed8d90.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [09 App Store · автопродление отключено](modules/ManageSubscription/atlas/atlas-managesubscription-db046fc75f.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [10 Автопродление отключено](modules/ManageSubscription/atlas/atlas-managesubscription-afb913e2aa.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [11 Ошибка операции](modules/ManageSubscription/atlas/atlas-managesubscription-4bec9461e5.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| SubscriptionRecovery | [01 Начальное состояние](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-0b31ba96fa.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [02 Создание ключа](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-eabcd2f2c6.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [03 Создан ключ](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-5e81636cda.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [04 Восстановление](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-844267b67b.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [05 Ошибка](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-bf22dfeeba.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [06 Ошибка · ключ сохранён](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-a368edb595.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| Storage | [01 StorageReadyState](modules/Storage/atlas/atlas-storage-e3878f9ab6.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [02 StorageLoadingState](modules/Storage/atlas/atlas-storage-d0255baf12.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [03 StorageFailedState](modules/Storage/atlas/atlas-storage-81abc7153c.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| StorageClearProtocols | [01 StorageClearProtocolsState](modules/StorageClearProtocols/atlas/atlas-storageclearprotocols-4d149c4a17.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/StorageClearProtocols/Preview/StorageClearProtocolsPreview.swift) |
| StorageClearAll | [01 StorageClearAllState](modules/StorageClearAll/atlas/atlas-storageclearall-36506c3d0e.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/StorageClearAll/Preview/StorageClearAllPreview.swift) |
| About | [01 AboutState](modules/About/atlas/atlas-about-eb18083f1a.yaml) | [Preview](../ios/Doglyad/Application/Module/About/Preview/AboutPreview.swift) |
| SelectDateOfBirth | [01 SelectDateOfBirthState](modules/SelectDateOfBirth/atlas/atlas-selectdateofbirth-4d2a5587eb.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectDateOfBirth/Preview/SelectDateOfBirthPreview.swift) |
| SelectTemplate | [01 SelectTemplateLoadingState](modules/SelectTemplate/atlas/atlas-selecttemplate-fe15c31af1.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| SelectTemplate | [02 SelectTemplateFailedState](modules/SelectTemplate/atlas/atlas-selecttemplate-4d9e2cd5e4.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| SelectTemplate | [03 SelectTemplateEmptyState](modules/SelectTemplate/atlas/atlas-selecttemplate-c677e31a90.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| SelectTemplate | [04 SelectTemplateContentState](modules/SelectTemplate/atlas/atlas-selecttemplate-9d2d4a513c.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| ImportMedia | [01 ImportMediaState](modules/ImportMedia/atlas/atlas-importmedia-a9fb9b7616.yaml) | [Preview](../ios/Doglyad/Application/Module/ImportMedia/Preview/ImportMediaPreview.swift) |
| Permission | [01 PermissionState](modules/Permission/atlas/atlas-permission-dc09229dfa.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Preview/PermissionPreview.swift) |
| Permission | [02 Permission · speech](modules/Permission/atlas/atlas-permission-8656f97c64.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Preview/PermissionPreview.swift) |
| Permission | [03 Permission · photoLibrary](modules/Permission/atlas/atlas-permission-3554c50972.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Preview/PermissionPreview.swift) |
| ScanCamera | [01 ScanCameraPreparingState](modules/ScanCamera/atlas/atlas-scancamera-887053334f.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [02 ScanCameraReadyState](modules/ScanCamera/atlas/atlas-scancamera-6ecb9a3bd7.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [03 ScanCameraCapturingState](modules/ScanCamera/atlas/atlas-scancamera-2c11689d15.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [04 ScanCameraStoppedState](modules/ScanCamera/atlas/atlas-scancamera-0d371deaf0.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| PhotoLibraryPicker | [01 PhotoLibraryPickerState](modules/PhotoLibraryPicker/atlas/atlas-photolibrarypicker-022398461f.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Library/Preview/PhotoLibraryPickerPreview.swift) |
| PhotoView | [01 PhotoViewState](modules/PhotoView/atlas/atlas-photoview-96ab4ea43b.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [02 PhotoViewRemarks](modules/PhotoView/atlas/atlas-photoview-23a69732c2.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [03 PhotoViewSavedReport](modules/PhotoView/atlas/atlas-photoview-6eb3a4e379.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [04 PhotoViewPortrait](modules/PhotoView/atlas/atlas-photoview-a3683bb854.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [05 PhotoViewSquare](modules/PhotoView/atlas/atlas-photoview-dd0eb85c9e.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoRemark | [01 PhotoRemarkState](modules/PhotoRemark/atlas/atlas-photoremark-7c0d0b5528.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoRemark/Preview/PhotoRemarkPreview.swift) |
| ScanSpeech | [01 Проверка модели](modules/ScanSpeech/atlas/atlas-scanspeech-f3253b2782.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [02 Загрузка без прогресса](modules/ScanSpeech/atlas/atlas-scanspeech-e3120ff04d.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [03 ScanSpeechPreparingModelState](modules/ScanSpeech/atlas/atlas-scanspeech-f45a93c961.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [04 Загрузка модели в память](modules/ScanSpeech/atlas/atlas-scanspeech-50e5e3c571.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [05 ScanSpeechModelPreparationFailedState](modules/ScanSpeech/atlas/atlas-scanspeech-c4ff582aef.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [06 ScanSpeechReadyState](modules/ScanSpeech/atlas/atlas-scanspeech-527388b442.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [07 ScanSpeechPreparingRecordingState](modules/ScanSpeech/atlas/atlas-scanspeech-5214dc81f5.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [08 ScanSpeechRecordingState](modules/ScanSpeech/atlas/atlas-scanspeech-7f2ced87c9.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [09 ScanSpeechTranscribingState](modules/ScanSpeech/atlas/atlas-scanspeech-d14902fd9a.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [10 ScanSpeechAutomaticParsingState](modules/ScanSpeech/atlas/atlas-scanspeech-849290d205.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [11 ScanSpeechReviewTranscriptState](modules/ScanSpeech/atlas/atlas-scanspeech-0b2ba9583c.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [12 ScanSpeechReviewParsingState](modules/ScanSpeech/atlas/atlas-scanspeech-a66545cfa7.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ReportReceived | [01 Генерация · ожидание первого токена](modules/ReportReceived/atlas/atlas-reportreceived-2ab1ec595f.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [02 Генерация · первый токен](modules/ReportReceived/atlas/atlas-reportreceived-39ebed2d82.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [03 Генерация · описание](modules/ReportReceived/atlas/atlas-reportreceived-07e73daa3d.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [04 Генерация · заключение](modules/ReportReceived/atlas/atlas-reportreceived-c6a999d993.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [05 Готовый протокол](modules/ReportReceived/atlas/atlas-reportreceived-d3704636e1.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [06 Готовый протокол · рекомендации и замечания](modules/ReportReceived/atlas/atlas-reportreceived-61afa1369a.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [07 Готовый протокол · из деталей](modules/ReportReceived/atlas/atlas-reportreceived-40f2fc3312.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [08 Готовый протокол · почта не задана](modules/ReportReceived/atlas/atlas-reportreceived-4cd463b00f.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [09 Готовый протокол · почта требует Pro](modules/ReportReceived/atlas/atlas-reportreceived-b176ef4e3b.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [10 Готовый протокол · отправка недоступна](modules/ReportReceived/atlas/atlas-reportreceived-8a1936d3c0.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [11 Отправка на почту](modules/ReportReceived/atlas/atlas-reportreceived-b7da0ca714.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [12 Ошибка отправки на почту](modules/ReportReceived/atlas/atlas-reportreceived-94ac3b0472.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [13 Генерация прервана · без текста](modules/ReportReceived/atlas/atlas-reportreceived-afacc093cc.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [14 Генерация прервана · частичный текст](modules/ReportReceived/atlas/atlas-reportreceived-4c9fcd8fe3.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [15 Ошибка генерации · без текста](modules/ReportReceived/atlas/atlas-reportreceived-183c7bec7c.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [16 Ошибка генерации · частичный текст](modules/ReportReceived/atlas/atlas-reportreceived-01ea2a847a.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| ReportReceived | [17 Генерация отменена](modules/ReportReceived/atlas/atlas-reportreceived-9b2b54e80e.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportReceived/Preview/ReportReceivedPreview.swift) |
| Share | [01 ShareReadyState](modules/Share/atlas/atlas-share-ac05fd8940.yaml) | [Preview](../ios/Doglyad/Application/Module/Share/Preview/SharePreview.swift) |
| Share | [02 ShareSendingState](modules/Share/atlas/atlas-share-ef49654fd7.yaml) | [Preview](../ios/Doglyad/Application/Module/Share/Preview/SharePreview.swift) |
| Share | [03 ShareFailedState](modules/Share/atlas/atlas-share-ba8c14a5dc.yaml) | [Preview](../ios/Doglyad/Application/Module/Share/Preview/SharePreview.swift) |
| RequestLimitExceeded | [01 RequestLimitExceededState](modules/RequestLimitExceeded/atlas/atlas-requestlimitexceeded-318f21618a.yaml) | [Preview](../ios/Doglyad/Application/Module/LimitExceeded/Preview/RequestLimitExceededPreview.swift) |
| LegalUpdate | [01 LegalUpdateAwaitingAcceptanceState](modules/LegalUpdate/atlas/atlas-legalupdate-fe1e41baa7.yaml) | [Preview](../ios/Doglyad/Application/Module/LegalUpdate/Preview/LegalUpdatePreview.swift) |
| LegalUpdate | [02 LegalUpdateLoadingState](modules/LegalUpdate/atlas/atlas-legalupdate-8a74474207.yaml) | [Preview](../ios/Doglyad/Application/Module/LegalUpdate/Preview/LegalUpdatePreview.swift) |
| LegalUpdate | [03 LegalUpdateFailedState](modules/LegalUpdate/atlas/atlas-legalupdate-c43a01a6c4.yaml) | [Preview](../ios/Doglyad/Application/Module/LegalUpdate/Preview/LegalUpdatePreview.swift) |
| NewVersion | [01 NewVersionState](modules/NewVersion/atlas/atlas-newversion-affc69b859.yaml) | [Preview](../ios/Doglyad/Application/Module/NewVersion/Preview/NewVersionPreview.swift) |
