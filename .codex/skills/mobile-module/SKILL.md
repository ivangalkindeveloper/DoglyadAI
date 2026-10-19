---
name: mobile-module
description: Create a mobile application module according to Doglyad conventions. Scaffold an iOS SwiftUI and MVVM screen or bottom sheet with Screen, ScreenView, ViewModel, and Arguments types and register it in the router. Use when adding a mobile screen, bottom sheet, or navigation module.
---

# Create a mobile module

Create and connect an iOS feature using the current rules in the repository's `AGENTS.md`. Add Android instructions when the project gains an Android client.

## Choose the module

Determine the PascalCase feature name, whether navigation presents a screen or bottom sheet, and its incoming data and result callbacks. Arguments may be empty. Follow existing grouping under `ios/Doglyad/Application/Module/`.

Read `Module/Settings/Settings/` for a screen or `Module/Select/SelectNeuralModel/` for a bottom sheet. Read `Application/Application/ViewModel/DModuleViewModel.swift` before constructing a view model; its initializer defines the shared lifecycle dependencies.

## Required structure

Every module contains four types, each in its own file:

- `FeatureScreen` or `FeatureBottomSheet`: accepts `FeatureArguments`, creates the feature view model, and passes it to the presentation view.
- `FeatureArguments`: incoming data and callbacks, conforming to `RouteArgumentsProtocol`; its name does not contain `Screen` or `BottomSheet`.
- `FeatureScreenView` or `FeatureBottomSheetView`: owns the received model through `@StateObject` and injects the same instance with `.environmentObject`.
- `FeatureViewModel`: `@MainActor`, inherits from `DModuleViewModel`, and owns presentation logic and interaction methods.

Descendant views obtain their feature view model only through private `@EnvironmentObject`. Do not pass it to descendant constructors or store it as `@ObservedObject`. Externally owned controllers are distinct from feature view models.

Use `DView` and declare its theme directly as `@EnvironmentObject var theme: DTheme`. Other environment objects are private. Views contain properties, initializers, and declarative layout. Move methods into the feature view model; express reusable rendering through separate view types. Framework-adapter exceptions are defined in `AGENTS.md`.

Arrange public interactions in visible order from the top of the screen to the bottom. Initialization and lifecycle methods come first, private helpers last. Let the owning view model determine visibility; presentation views use its flags.

## Dependencies and communication

Pass the whole `DependencyContainer` when the feature needs its repositories or managers. Root view models use the `RootViewModel` suffix (`{FeatureName}RootViewModel`), for example `ApplicationRootViewModel`. Entry views may read root objects from the environment to supply getter, update, and observation closures to the feature view-model initializer. Never pass or store a root view-model instance in a module view model.

`DModuleViewModel` receives subscription getter, observer, update, neural-settings getter, and request-count callback closures. Preserve reactive changes using cancellable observation closures, as in `ScanScreen` and `ScanViewModel`. Do not bypass these boundaries through the container.

Modules communicate through closures in the destination's `FeatureArguments`, forwarded to its initializer. Do not call or retain another module's view model.

## UI and localization

Build layout from `DoglyadUI` components and styling, using SwiftUI for composition. Use design-system shimmer for loading states. Add missing generic primitives to DoglyadUI; consult its target-membership instructions in `AGENTS.md` when adding files.

Application views shared between modules belong in `ios/Doglyad/Application/Application/View/`. A view used by one module stays in that module and starts with its feature name. Visual resources come through DoglyadUI or the application asset catalog. Networking uses `DoglyadNetwork`; persistence uses `DoglyadDatabase`.

Access backend strings through `L10N` and `L10NKey`. Add English and Russian keys to `backend/main/config/{development,production}/{en,ru}/l10n_application.json` and update `L10NKey`. Use `{featureName}{KeyName}` with the required semantic suffixes; generic buttons use `button`. Local `Localizable.xcstrings` is reserved for bootstrap errors and mandatory major-version updates. Before the first release, migrate server and client keys together without compatibility aliases.

## Navigation and verification

Register the destination in `Application/Application/Router/RouteType.swift` and handle it exhaustively in `RouterBuilder.swift`. Cast mandatory arguments with `as!` and optional inputs with `as?`, following neighboring routes. Navigate through the coordinator with destination arguments carrying callbacks.

Run `make format-ios`, `make lint-ios`, and applicable checks from [build-verify](../build-verify/SKILL.md). The synchronized application folder discovers module files automatically; DoglyadUI has membership exception lists. Report feature files, navigation registration, and verification. Do not commit or deploy unless requested.
