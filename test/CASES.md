# Регресс-кейсы

Описание сценариев каждого модуля и статус автоматизации: [COVERAGE.md](COVERAGE.md). Ниже перечислены исполняемые flows и отдельные Preview-снимки.

Список создаёт `python3 test/scripts/catalog.py`. Это перечень проверок, а не результат запуска.

Платформа: iOS. Модулей: 39. Функциональных кейсов с вводным сценарием: 129. Кейсов отображения: 207.

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

## Отображение модулей и общих компонентов

Каждый кейс запускает существующий Preview модуля или компонента, проверяет его идентификатор и делает снимок.
Эти кейсы не проверяют переходы в состояния или работу внешних интеграций. Ограничения описаны в [README](README.md#покрытие-и-ограничения).

| Модуль | Состояние и YAML | Исходник |
|---|---|---|
| ApplicationSplash | [01 ApplicationSplash](modules/ApplicationSplash/atlas/atlas-applicationsplash-686139405c.yaml) | [Preview](../ios/Doglyad/Application/Application/Application/Preview/ApplicationSplashPreview.swift) |
| OnBoarding | [01 OnBoardingInitialState](modules/OnBoarding/atlas/atlas-onboarding-ba6f4599a6.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [02 OnBoardingSecondState](modules/OnBoarding/atlas/atlas-onboarding-22931274f9.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [03 OnBoardingLegalState](modules/OnBoarding/atlas/atlas-onboarding-64023d86bc.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [04 Согласие принято](modules/OnBoarding/atlas/atlas-onboarding-6491f10c7e.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [05 OnBoardingExaminationTypeState](modules/OnBoarding/atlas/atlas-onboarding-393cd796b5.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [06 OnBoardingFinalState](modules/OnBoarding/atlas/atlas-onboarding-827b47baa8.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [07 OnBoardingLoadingState](modules/OnBoarding/atlas/atlas-onboarding-45d0b3daf8.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| OnBoarding | [08 OnBoardingFailedState](modules/OnBoarding/atlas/atlas-onboarding-660276f3c0.yaml) | [Preview](../ios/Doglyad/Application/Module/OnBoarding/Preview/OnBoardingPreview.swift) |
| WebDocument | [01 WebDocumentLoadingState](modules/WebDocument/atlas/atlas-webdocument-74aa813450.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [02 WebDocumentSuccessState](modules/WebDocument/atlas/atlas-webdocument-ef15ad0e62.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| WebDocument | [03 WebDocumentFailedState](modules/WebDocument/atlas/atlas-webdocument-8b51e76f05.yaml) | [Preview](../ios/Doglyad/Application/Module/WebDocument/Preview/WebDocumentPreview.swift) |
| SelectUSExaminationType | [01 SelectUSExaminationTypeRecentTypesLoadingState](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-75a49c9136.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| SelectUSExaminationType | [02 SelectUSExaminationTypeFailedState](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-b3093417e8.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| SelectUSExaminationType | [03 SelectUSExaminationTypeContentState](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-966f691d4f.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| SelectUSExaminationType | [04 SelectUSExaminationTypeSelectionLoadingState](modules/SelectUSExaminationType/atlas/atlas-selectusexaminationtype-31422ce04b.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectUSExaminationType/Preview/SelectUSExaminationTypePreview.swift) |
| Paywall | [01 PaywallCatalogLoadingState](modules/Paywall/atlas/atlas-paywall-c6c810cc24.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [02 PaywallLoadingFailedState](modules/Paywall/atlas/atlas-paywall-ae8aab4ea7.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [03 PaywallSuccessState](modules/Paywall/atlas/atlas-paywall-497f187946.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [04 Русский](modules/Paywall/atlas/atlas-paywall-6da140fdd4.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [05 Каталог без предложений](modules/Paywall/atlas/atlas-paywall-5687a8e2b0.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [06 Обновление тарифов](modules/Paywall/atlas/atlas-paywall-5b7e4afd88.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [07 PaywallPurchaseLoadingState](modules/Paywall/atlas/atlas-paywall-7a967dcbc3.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [08 PaywallPendingState](modules/Paywall/atlas/atlas-paywall-93c932ac6f.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [09 PaywallOperationFailedState](modules/Paywall/atlas/atlas-paywall-6e1176fbf4.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [10 PaywallPaymentCheckLoadingState](modules/Paywall/atlas/atlas-paywall-e578e549c9.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [11 PaywallRestoreLoadingState](modules/Paywall/atlas/atlas-paywall-78d1fb4e34.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Paywall | [12 Восстановление без каталога](modules/Paywall/atlas/atlas-paywall-9567bc35b4.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/Paywall/Preview/PaywallPreview.swift) |
| Scan | [01 ScanInitializationLoadingState](modules/Scan/atlas/atlas-scan-feca1f0f09.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [02 ScanInitializationFailedState](modules/Scan/atlas/atlas-scan-eaa41d57a9.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [03 ScanInitialState](modules/Scan/atlas/atlas-scan-5f36357d96.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [04 ScanGenerationLoadingState](modules/Scan/atlas/atlas-scan-c2a6c2af6d.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [05 ScanReportSaveLoadingState](modules/Scan/atlas/atlas-scan-485269c5a1.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [06 ScanClearLoadingState](modules/Scan/atlas/atlas-scan-18516644a6.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [07 ScanFailedState](modules/Scan/atlas/atlas-scan-6307577c52.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
| Scan | [08 Кнопка добавления снимков](modules/Scan/atlas/atlas-scan-e7a654c429.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/Scan/Preview/ScanPreview.swift) |
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
| History | [08 Карточка исследования](modules/History/atlas/atlas-history-be53ad2f71.yaml) | [Preview](../ios/Doglyad/Application/Module/History/Preview/HistoryPreview.swift) |
| ReportDetail | [01 ReportDetailContentState](modules/ReportDetail/atlas/atlas-reportdetail-3c375c3930.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [02 ReportDetailSaveLoadingState](modules/ReportDetail/atlas/atlas-reportdetail-f8ef2d844c.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [03 ReportDetailGenerationLoadingState](modules/ReportDetail/atlas/atlas-reportdetail-059db56064.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [04 ReportDetailFailedState](modules/ReportDetail/atlas/atlas-reportdetail-eb8db8a872.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [05 Раскрываемый Markdown](modules/ReportDetail/atlas/atlas-reportdetail-e421972101.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [06 Одна строка — лимит 3](modules/ReportDetail/atlas/atlas-reportdetail-d0ceefabae.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [07 Три строки — лимит 3](modules/ReportDetail/atlas/atlas-reportdetail-52cd329097.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [08 Четыре строки — лимит 3](modules/ReportDetail/atlas/atlas-reportdetail-f9e70832f7.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [09 Длинный текст — ширина 360](modules/ReportDetail/atlas/atlas-reportdetail-ed9317f52e.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [10 Длинный текст — ширина 260](modules/ReportDetail/atlas/atlas-reportdetail-7c5f22bfb6.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [11 Длинный текст — лимит 1](modules/ReportDetail/atlas/atlas-reportdetail-261282d155.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| ReportDetail | [12 Карточка ответа модели](modules/ReportDetail/atlas/atlas-reportdetail-92de649adf.yaml) | [Preview](../ios/Doglyad/Application/Module/Report/ReportDetail/Preview/ReportDetailPreview.swift) |
| TemplateList | [01 TemplateListLoadingState](modules/TemplateList/atlas/atlas-templatelist-ae8997d3b5.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [02 TemplateListFailedState](modules/TemplateList/atlas/atlas-templatelist-03855e8c3f.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [03 TemplateListEmptyState](modules/TemplateList/atlas/atlas-templatelist-1f8dfe97cf.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateList | [04 TemplateListContentState](modules/TemplateList/atlas/atlas-templatelist-84499cf1eb.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateList/Preview/TemplateListPreview.swift) |
| TemplateAdd | [01 TemplateAddInitializationLoadingState](modules/TemplateAdd/atlas/atlas-templateadd-52b30ebbfb.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| TemplateAdd | [02 TemplateAddInitialState](modules/TemplateAdd/atlas/atlas-templateadd-2beeb4e83a.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| TemplateAdd | [03 TemplateAddSaveLoadingState](modules/TemplateAdd/atlas/atlas-templateadd-163860b6a4.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| TemplateAdd | [04 TemplateAddFailedState](modules/TemplateAdd/atlas/atlas-templateadd-780cf44421.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateAdd/Preview/TemplateAddPreview.swift) |
| ReadyMadeTemplateList | [01 ReadyMadeTemplateListLoadingState](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-b2303cf106.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [02 ReadyMadeTemplateListFailedState](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-579ef5fc0d.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [03 Каталог пуст](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-6db21dc344.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [04 ReadyMadeTemplateListSuccessState](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-ec70b9ae6e.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [05 Раскрываемый текст шаблона](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-d34818bc9a.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| ReadyMadeTemplateList | [06 Карточка готового шаблона](modules/ReadyMadeTemplateList/atlas/atlas-readymadetemplatelist-24a75b07c0.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/ReadyMadeTemplateList/Preview/ReadyMadeTemplateListPreview.swift) |
| TemplateEdit | [01 TemplateEditInitializationLoadingState](modules/TemplateEdit/atlas/atlas-templateedit-6d4925d7d8.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [02 TemplateEditInitializationFailedState](modules/TemplateEdit/atlas/atlas-templateedit-e453ba653b.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [03 TemplateEditInitialState](modules/TemplateEdit/atlas/atlas-templateedit-b372e7de63.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [04 TemplateEditSaveLoadingState](modules/TemplateEdit/atlas/atlas-templateedit-06a8956f3e.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [05 TemplateEditDeleteLoadingState](modules/TemplateEdit/atlas/atlas-templateedit-d827e6844a.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateEdit | [06 TemplateEditFailedState](modules/TemplateEdit/atlas/atlas-templateedit-ddace9f930.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TemplateEdit/Preview/TemplateEditPreview.swift) |
| TemplateDelete | [01 TemplateDeleteDefaultState](modules/TemplateDelete/atlas/atlas-templatedelete-99e3dc49e5.yaml) | [Preview](../ios/Doglyad/Application/Module/Template/TempalteDelete/Preview/TemplateDeletePreview.swift) |
| UserSettings | [01 UserSettingsInitialState](modules/UserSettings/atlas/atlas-usersettings-765706ab8d.yaml) | [Preview](../ios/Doglyad/Application/Module/UserSettings/Preview/UserSettingsPreview.swift) |
| UserSettings | [02 UserSettingsLoadingState](modules/UserSettings/atlas/atlas-usersettings-0a6fe5a8ec.yaml) | [Preview](../ios/Doglyad/Application/Module/UserSettings/Preview/UserSettingsPreview.swift) |
| UserSettings | [03 UserSettingsFailedState](modules/UserSettings/atlas/atlas-usersettings-60c11651e6.yaml) | [Preview](../ios/Doglyad/Application/Module/UserSettings/Preview/UserSettingsPreview.swift) |
| SettingsAI | [01 SettingsAIInitialState](modules/SettingsAI/atlas/atlas-settingsai-2fdb6b688a.yaml) | [Preview](../ios/Doglyad/Application/Module/Settings/SettingsAI/Preview/SettingsAIPreview.swift) |
| SettingsAI | [02 SettingsAILoadingState](modules/SettingsAI/atlas/atlas-settingsai-a8c8bdedf3.yaml) | [Preview](../ios/Doglyad/Application/Module/Settings/SettingsAI/Preview/SettingsAIPreview.swift) |
| SettingsAI | [03 SettingsAIFailedState](modules/SettingsAI/atlas/atlas-settingsai-1c1e50d046.yaml) | [Preview](../ios/Doglyad/Application/Module/Settings/SettingsAI/Preview/SettingsAIPreview.swift) |
| SelectTranscriber | [01 SelectTranscriberInitialState](modules/SelectTranscriber/atlas/atlas-selecttranscriber-36a9930fdd.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTranscriber/Preview/SelectTranscriberPreview.swift) |
| SelectTranscriptParser | [01 SelectTranscriptParserDefaultState](modules/SelectTranscriptParser/atlas/atlas-selecttranscriptparser-dbf7d13abf.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTranscriptParser/Preview/SelectTranscriptParserPreview.swift) |
| SelectNeuralModel | [01 SelectNeuralModelInitialState](modules/SelectNeuralModel/atlas/atlas-selectneuralmodel-9f31658382.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectNeuralModel/Preview/SelectNeuralModelPreview.swift) |
| SelectNeuralModel | [02 SelectNeuralModelSelectionLoadingState](modules/SelectNeuralModel/atlas/atlas-selectneuralmodel-9b5bc61d7d.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectNeuralModel/Preview/SelectNeuralModelPreview.swift) |
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
| ManageSubscription | [12 Восстановление покупок](modules/ManageSubscription/atlas/atlas-managesubscription-dd3d4c5e50.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [13 Управление автопродлением](modules/ManageSubscription/atlas/atlas-managesubscription-5fafc5b541.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| ManageSubscription | [14 Запрос возврата](modules/ManageSubscription/atlas/atlas-managesubscription-cc9a19763b.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/ManageSubscription/Preview/ManageSubscriptionPreview.swift) |
| SubscriptionRecovery | [01 Начальное состояние](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-0b31ba96fa.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [02 Создание ключа](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-eabcd2f2c6.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [03 Создан ключ](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-5e81636cda.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [04 Восстановление](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-844267b67b.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [05 Ошибка](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-bf22dfeeba.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| SubscriptionRecovery | [06 Ошибка · ключ сохранён](modules/SubscriptionRecovery/atlas/atlas-subscriptionrecovery-a368edb595.yaml) | [Preview](../ios/Doglyad/Application/Module/Subscription/SubscriptionRecovery/Preview/SubscriptionRecoveryPreview.swift) |
| Storage | [01 StorageInitialState](modules/Storage/atlas/atlas-storage-7972f70483.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [02 StorageProtocolsClearLoadingState](modules/Storage/atlas/atlas-storage-284fc5d091.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [03 StorageSpeechModelDeleteLoadingState](modules/Storage/atlas/atlas-storage-5c0ab02675.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [04 StorageAllClearLoadingState](modules/Storage/atlas/atlas-storage-b49d676ce1.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| Storage | [05 StorageFailedState](modules/Storage/atlas/atlas-storage-81abc7153c.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/Storage/Preview/StoragePreview.swift) |
| StorageClearProtocols | [01 StorageClearProtocolsDefaultState](modules/StorageClearProtocols/atlas/atlas-storageclearprotocols-8fdb5d5c0d.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/StorageClearProtocols/Preview/StorageClearProtocolsPreview.swift) |
| StorageClearAll | [01 StorageClearAllDefaultState](modules/StorageClearAll/atlas/atlas-storageclearall-0983efdd26.yaml) | [Preview](../ios/Doglyad/Application/Module/Storage/StorageClearAll/Preview/StorageClearAllPreview.swift) |
| About | [01 AboutDefaultState](modules/About/atlas/atlas-about-54651a6e4c.yaml) | [Preview](../ios/Doglyad/Application/Module/About/Preview/AboutPreview.swift) |
| SelectDateOfBirth | [01 SelectDateOfBirthDefaultState](modules/SelectDateOfBirth/atlas/atlas-selectdateofbirth-0ea35caf8b.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectDateOfBirth/Preview/SelectDateOfBirthPreview.swift) |
| SelectTemplate | [01 SelectTemplateTemplatesLoadingState](modules/SelectTemplate/atlas/atlas-selecttemplate-968bcb6990.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| SelectTemplate | [02 SelectTemplateFailedState](modules/SelectTemplate/atlas/atlas-selecttemplate-4d9e2cd5e4.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| SelectTemplate | [03 SelectTemplateEmptyState](modules/SelectTemplate/atlas/atlas-selecttemplate-c677e31a90.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| SelectTemplate | [04 SelectTemplateContentState](modules/SelectTemplate/atlas/atlas-selecttemplate-9d2d4a513c.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| SelectTemplate | [05 Применение выбранного шаблона](modules/SelectTemplate/atlas/atlas-selecttemplate-8391a67f95.yaml) | [Preview](../ios/Doglyad/Application/Module/Select/SelectTemplate/Preview/SelectTemplatePreview.swift) |
| ImportMedia | [01 ImportMediaDefaultState](modules/ImportMedia/atlas/atlas-importmedia-0eb2f0b208.yaml) | [Preview](../ios/Doglyad/Application/Module/ImportMedia/Preview/ImportMediaPreview.swift) |
| Permission | [01 PermissionDefaultState](modules/Permission/atlas/atlas-permission-9fe14ba257.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Preview/PermissionPreview.swift) |
| Permission | [02 Permission · speech](modules/Permission/atlas/atlas-permission-8656f97c64.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Preview/PermissionPreview.swift) |
| Permission | [03 Permission · photoLibrary](modules/Permission/atlas/atlas-permission-3554c50972.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Preview/PermissionPreview.swift) |
| ScanCamera | [01 ScanCameraPreparationLoadingState](modules/ScanCamera/atlas/atlas-scancamera-a3057432bc.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [02 ScanCameraReadyState](modules/ScanCamera/atlas/atlas-scancamera-6ecb9a3bd7.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [03 ScanCameraCaptureLoadingState](modules/ScanCamera/atlas/atlas-scancamera-fbb53f1d03.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| ScanCamera | [04 ScanCameraStoppedState](modules/ScanCamera/atlas/atlas-scancamera-0d371deaf0.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanCamera/Preview/ScanCameraPreview.swift) |
| PhotoLibraryPicker | [01 PhotoLibraryPickerDefaultState](modules/PhotoLibraryPicker/atlas/atlas-photolibrarypicker-ad3ba7c6e9.yaml) | [Preview](../ios/Doglyad/Application/Module/Permission/Library/Preview/PhotoLibraryPickerPreview.swift) |
| PhotoView | [01 PhotoViewInitialState](modules/PhotoView/atlas/atlas-photoview-9036f21d8e.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [02 PhotoViewRemarks](modules/PhotoView/atlas/atlas-photoview-23a69732c2.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [03 PhotoViewSavedReport](modules/PhotoView/atlas/atlas-photoview-6eb3a4e379.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [04 PhotoViewPortrait](modules/PhotoView/atlas/atlas-photoview-a3683bb854.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoView | [05 PhotoViewSquare](modules/PhotoView/atlas/atlas-photoview-dd0eb85c9e.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoView/Preview/PhotoViewPreview.swift) |
| PhotoRemark | [01 PhotoRemarkDefaultState](modules/PhotoRemark/atlas/atlas-photoremark-50b9e1bf86.yaml) | [Preview](../ios/Doglyad/Application/Module/PhotoRemark/Preview/PhotoRemarkPreview.swift) |
| ScanSpeech | [01 Проверка модели](modules/ScanSpeech/atlas/atlas-scanspeech-f3253b2782.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [02 Загрузка без прогресса](modules/ScanSpeech/atlas/atlas-scanspeech-e3120ff04d.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [03 ScanSpeechModelLoadingState](modules/ScanSpeech/atlas/atlas-scanspeech-0f7c7bbd68.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [04 Загрузка модели в память](modules/ScanSpeech/atlas/atlas-scanspeech-50e5e3c571.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [05 ScanSpeechModelPreparationFailedState](modules/ScanSpeech/atlas/atlas-scanspeech-c4ff582aef.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [06 ScanSpeechReadyState](modules/ScanSpeech/atlas/atlas-scanspeech-527388b442.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [07 ScanSpeechRecordingPreparationLoadingState](modules/ScanSpeech/atlas/atlas-scanspeech-d5eb7a84b9.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [08 ScanSpeechRecordingState](modules/ScanSpeech/atlas/atlas-scanspeech-7f2ced87c9.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [09 ScanSpeechTranscriptionLoadingState](modules/ScanSpeech/atlas/atlas-scanspeech-58cffebcfc.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [10 ScanSpeechAutomaticParsingLoadingState](modules/ScanSpeech/atlas/atlas-scanspeech-5656ebbe4d.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [11 ScanSpeechReviewTranscriptState](modules/ScanSpeech/atlas/atlas-scanspeech-0b2ba9583c.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [12 ScanSpeechReviewParsingLoadingState](modules/ScanSpeech/atlas/atlas-scanspeech-de6918e489.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [13 Нужно проверить](modules/ScanSpeech/atlas/atlas-scanspeech-2a18390cc1.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [14 Выбрано](modules/ScanSpeech/atlas/atlas-scanspeech-9cf249e2a8.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [15 Число и единицы](modules/ScanSpeech/atlas/atlas-scanspeech-547cc290c1.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [16 Сторона и отрицание](modules/ScanSpeech/atlas/atlas-scanspeech-2d4b3536aa.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [17 Несколько полей](modules/ScanSpeech/atlas/atlas-scanspeech-c860e9dcfa.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [18 Частичный результат](modules/ScanSpeech/atlas/atlas-scanspeech-dd77f0a008.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [19 Длинный клинический текст](modules/ScanSpeech/atlas/atlas-scanspeech-8a8db86235.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [20 Ничего не распознано](modules/ScanSpeech/atlas/atlas-scanspeech-0b3c217c69.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [21 Диктовка готова](modules/ScanSpeech/atlas/atlas-scanspeech-f4f1ae8c7f.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [22 Длинная прерванная запись](modules/ScanSpeech/atlas/atlas-scanspeech-cd201d1158.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [23 Речь не распознана](modules/ScanSpeech/atlas/atlas-scanspeech-042ba06a44.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
| ScanSpeech | [24 Разбор диктовки](modules/ScanSpeech/atlas/atlas-scanspeech-23c08fcada.yaml) | [Preview](../ios/Doglyad/Application/Module/Scan/ScanSpeech/Preview/ScanSpeechPreview.swift) |
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
| Share | [01 ShareInitialState](modules/Share/atlas/atlas-share-23af9c548c.yaml) | [Preview](../ios/Doglyad/Application/Module/Share/Preview/SharePreview.swift) |
| Share | [02 ShareLoadingState](modules/Share/atlas/atlas-share-1ad0f080b3.yaml) | [Preview](../ios/Doglyad/Application/Module/Share/Preview/SharePreview.swift) |
| Share | [03 ShareFailedState](modules/Share/atlas/atlas-share-ba8c14a5dc.yaml) | [Preview](../ios/Doglyad/Application/Module/Share/Preview/SharePreview.swift) |
| RequestLimitExceeded | [01 RequestLimitExceededDefaultState](modules/RequestLimitExceeded/atlas/atlas-requestlimitexceeded-9e84b5cf89.yaml) | [Preview](../ios/Doglyad/Application/Module/LimitExceeded/Preview/RequestLimitExceededPreview.swift) |
| LegalUpdate | [01 LegalUpdateAwaitingAcceptanceState](modules/LegalUpdate/atlas/atlas-legalupdate-fe1e41baa7.yaml) | [Preview](../ios/Doglyad/Application/Module/LegalUpdate/Preview/LegalUpdatePreview.swift) |
| LegalUpdate | [02 LegalUpdateLoadingState](modules/LegalUpdate/atlas/atlas-legalupdate-8a74474207.yaml) | [Preview](../ios/Doglyad/Application/Module/LegalUpdate/Preview/LegalUpdatePreview.swift) |
| LegalUpdate | [03 LegalUpdateFailedState](modules/LegalUpdate/atlas/atlas-legalupdate-c43a01a6c4.yaml) | [Preview](../ios/Doglyad/Application/Module/LegalUpdate/Preview/LegalUpdatePreview.swift) |
| NewVersion | [01 NewVersionDefaultState](modules/NewVersion/atlas/atlas-newversion-2dcd5c4751.yaml) | [Preview](../ios/Doglyad/Application/Module/NewVersion/Preview/NewVersionPreview.swift) |
| NeuralModelCard | [01 Доступны запросы](components/NeuralModelCard/atlas/atlas-neuralmodelcard-a1a1435738.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/NeuralModelCardPreview.swift) |
| NeuralModelCard | [02 Лимит запросов исчерпан](components/NeuralModelCard/atlas/atlas-neuralmodelcard-03aec08916.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/NeuralModelCardPreview.swift) |
| SettingsAICard | [01 Настройки по умолчанию](components/SettingsAICard/atlas/atlas-settingsaicard-a538c5897a.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/SettingsAICardPreview.swift) |
| SettingsAICard | [02 Markdown включён](components/SettingsAICard/atlas/atlas-settingsaicard-c7ef2017e3.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/SettingsAICardPreview.swift) |
| TemplateListItemCard | [01 Шаблон](components/TemplateListItemCard/atlas/atlas-templatelistitemcard-fff8b34d92.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/TemplateListItemCardPreview.swift) |
| TemplateListItemCard | [02 Выбранный шаблон](components/TemplateListItemCard/atlas/atlas-templatelistitemcard-7f6fc383fb.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/TemplateListItemCardPreview.swift) |
| NeuralModelValueRow | [01 Название модели](components/NeuralModelValueRow/atlas/atlas-neuralmodelvaluerow-2eea50c922.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/NeuralModelValueRowPreview.swift) |
| NeuralModelValueRow | [02 Числовое значение](components/NeuralModelValueRow/atlas/atlas-neuralmodelvaluerow-b1b676d3cf.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/NeuralModelValueRowPreview.swift) |
| SectionHeader | [01 Локализованный заголовок](components/SectionHeader/atlas/atlas-sectionheader-fc36b7a869.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/SectionHeaderPreview.swift) |
| SectionHeader | [02 Заголовок из конфигурации](components/SectionHeader/atlas/atlas-sectionheader-fc7ec09ca9.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/SectionHeaderPreview.swift) |
| ErrorBody | [01 Ошибка загрузки](components/ErrorBody/atlas/atlas-errorbody-bd54852c08.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/ErrorBodyPreview.swift) |
| ErrorPagination | [01 Ошибка подгрузки страницы](components/ErrorPagination/atlas/atlas-errorpagination-1068246ef6.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/ErrorPaginationPreview.swift) |
| ExpandableContent | [01 Одна строка — лимит 3](components/ExpandableContent/atlas/atlas-expandablecontent-d0ceefabae.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/ExpandableContentPreview.swift) |
| ExpandableContent | [02 Три строки — лимит 3](components/ExpandableContent/atlas/atlas-expandablecontent-52cd329097.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/ExpandableContentPreview.swift) |
| ExpandableContent | [03 Четыре строки — лимит 3](components/ExpandableContent/atlas/atlas-expandablecontent-f9e70832f7.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/ExpandableContentPreview.swift) |
| ExpandableContent | [04 Длинный текст — ширина 360](components/ExpandableContent/atlas/atlas-expandablecontent-ed9317f52e.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/ExpandableContentPreview.swift) |
| ExpandableContent | [05 Длинный текст — ширина 260](components/ExpandableContent/atlas/atlas-expandablecontent-7c5f22bfb6.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/ExpandableContentPreview.swift) |
| ExpandableContent | [06 Длинный текст — лимит 1](components/ExpandableContent/atlas/atlas-expandablecontent-261282d155.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/ExpandableContentPreview.swift) |
| ExpandableContent | [07 Markdown — лимит 3](components/ExpandableContent/atlas/atlas-expandablecontent-800e561772.yaml) | [Preview](../ios/Doglyad/Application/Application/View/Preview/ExpandableContentPreview.swift) |
