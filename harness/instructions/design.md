# Doglyad content design rules

## Design approach

Start from the clinician's goal and follow the product rules in [common.md](common.md#product-rules).
Use the existing design system and state composition described in [ios.md](ios.md#swift-ios).
Design the applicable initial, loading, content, empty, error and retry presentations together.
Keep entered data and useful loaded content when an operation fails.
Include each distinct presentation in the module's named previews.

## Screen patterns and required data

Identify the screen's main scenario before choosing its states. Distinguish required
data from supplementary data; the source (local storage or backend) does not decide
whether a failure should block the user. Local database I/O does not introduce a loading presentation.

- **Supplementary data:** Keep the main scenario available while optional data load
  or fail. Omit an unavailable section or use a general description. Do not disable
  the main controls, replace the screen, offer Retry, or show `DMessager` for these
  failures. For example, keep the complete examination-type catalog available if
  recent types cannot load or be recorded. Keep Settings navigation available if
  the report count cannot load; show the history card's purpose instead of a count.
  Repository failures still propagate; the owning view model explicitly handles
  this optional result without pretending that required persistence succeeded.
- **Required backend data:** When the whole screen depends on fetched backend entities, show
  sections or shimmer cards matching the loaded layout. Show no bottom buttons
  while the initial request or its retry loads. If the request fails, show
  `ErrorBodyView`, a primary Retry button in `DScreen.bottom` (or `DBottomSheet.bottom`),
  and the semantic error through `DMessager`.
- **Nonempty catalogs:** Design important catalogs as nonempty successful content.
  Examination types and subscription plans have no successful empty-list state or
  empty-list Preview. An invalid or unavailable required catalog is an error;
  do not fabricate entities, grant access, or present an empty success.
- **Possibly empty user lists:** Provide an explicit empty state when absence is
  valid. A clinician can have no saved reports or templates. Distinguish that valid
  result from a failed request. Pagination follows the rules below.

- **Forms with remembered values:** Show the usable form immediately while its last
  saved values (a form draft) load in the background. Scan follows this pattern.
  Keep fields, selectors, media controls, navigation, voice filling and the normal
  primary action available. Do not show blocking shimmer or primary-button progress
  for draft restoration. Apply a successfully loaded draft only to untouched fields
  and values, including examination type and photos. Preserve edits made while the
  read was pending, including text that the user typed and then cleared. An absent
  draft leaves the form usable with its normal defaults. Keep the old stored draft
  intact until the read succeeds; do not autosave the initial blank form over it.
  After merging, save edits made during the read. Background saving waits for the
  pending restoration before flushing these merged edits. Clearing or submitting the form
  invalidates a late restoration result. A read failure preserves the editable form
  and reports the failure through `DMessager`. Do not add a refresh button to the
  form. Retry restoration on the next screen appearance while preserving edits;
  keep the normal primary action available. Saved clinical report templates
  remain a separate feature from these remembered form values.

## Local operations and selection sheets

- Keep local database reads and writes asynchronous and throwing. Do not create
  loading states, show shimmer/spinners, or disable controls merely for local I/O.
  Keep existing content and forms usable. Handle failures through DMessager; use
  ErrorBodyView only when required screen content cannot be read.
- Protect duplicate writes and destructive operations with privately owned tasks
  and operation identities. Reject cancelled and stale callbacks. These guards
  do not drive visible disabled/loading flags. Use the existing
  `DModuleViewModel.performLocalOperation` for module-owned local operations. Apply only untouched remembered
  values and never overwrite edits with a delayed read. Announce success and
  dismiss a saved selection only after required persistence succeeds.
- Selection sheets for already available entities display their complete list
  immediately. Save the chosen entity without a loading phase or disabling other
  rows, then dismiss on success. Availability checks for device capabilities may
  enrich the list in the background without hiding existing choices.
- A template selection sheet opens only with a nonempty list. If its local read
  finds no remaining matching templates, close the sheet rather than display an
  empty selection screen. Do not invent a spinner for this read.
- Network requests may have loading states. Onboarding completion keeps its loading phase while it refreshes subscription status from the backend. Keep meaningful progress for the
  explicitly supported long camera and speech operations, including model download,
  loading into memory, microphone preparation and transcription. Ordinary database
  I/O has no such exception.
- Paywall displays the subscription catalog throughout purchase/restoration and
  verification, with one checkout loading presentation. Provider pending/checking
  details remain internal. Verify the exact purchase before granting access; do
  not expose separate provider-status screens or a manual payment-check action.

## Button availability and progress

- `isDisabled` stops the user from continuing the scenario on the current screen.
- `isLoading` indicates that the scenario continues asynchronously while the next data load. Keep the button's enabled appearance and show its progress indicator.
- Never drive `isDisabled` and `isLoading` with the same flag or equivalent loading condition. Do not disable a button merely because it shows loading. Independent validation or availability restrictions apply when the button is not loading.
- During a blocking main operation, disable affected cards and input fields. Keep Back available. When loading continues an existing primary action, keep that button available with `isLoading: true`. Supplementary loads never block the main scenario. Prevent duplicate side effects in the control and view model without giving the loading button the disabled appearance.
- Other actions may disappear or move with an animation during loading. For example, move the voice-filling button down while hiding it. Use the existing view-model state animation and view transitions.

## Loading cards and pagination

- Use shimmer placeholders supplied by `DoglyadUI`. Render loading cards only where the loaded content uses cards. For plain text or HTML documents, imitate headings and paragraphs without card fills, borders or card padding.
- Match each loading card to its loaded counterpart: hierarchy, image positions, text rows, spacing, padding and card shape. Keep loading geometry as close to loaded content as possible.
- Give text placeholders different lengths. Do not stretch every shimmer line across the card. Imitate the text that will occupy the card.
- For backend pagination, keep loaded cards interactive and visible. Append shimmer cards matching the loaded cards for the pending page. Use the same loading-card implementation for initial and next-page requests. Local database pagination introduces no loading state or disabled cards.

## Errors and retry actions

- Show errors affecting the main scenario through `DMessager`, using their semantic descriptions. Do not duplicate an operation error in a red inline label. Supplementary-data failures follow the silent fallback pattern above. Cancellation and ignored stale results remain normal control flow, not errors.
- Use the shared `ErrorBodyView` when failed data are required for the entire screen and no useful content can be displayed. For example, use it when the initial report history cannot load from storage or the network.
- Put the full-screen error's retry/refresh action in `DScreen.bottom`. Always use the primary button style. For a bottom sheet, use the equivalent `DBottomSheet.bottom` placement and primary style.
- A retry/refresh button belongs only to an error state. Do not invent a primary button for initial loading or show Retry with `isLoading: true`. Hide Retry while the retry request loads; show it again only if that request fails. Screens without a normal primary action have no bottom button during loading or successful content.
- When the next page fails, keep existing items and show `ErrorPaginationView` at the failed section. Also show the error through `DMessager`.
- For a data-entry form, report failures only through `DMessager`. Never replace the form with `ErrorBodyView` or an inline error panel. Preserve the form, controllers and entered values so the user can correct or retry the operation. An initialization retry must not overwrite edits made after the failure.
- An operation failure must preserve previously loaded content or generated results needed for retry. A retry must repeat only the failed operation.

- ReportReceived is a loading-layout exception: before the first generated token, show the shimmering “Generating report” text aligned to the leading edge, without shimmer cards. Show no bottom controls during generation; show actions only after completion or a generation error. During email delivery, show loading only on the email action; disable opening and copying the completed report without showing loading on those buttons.
