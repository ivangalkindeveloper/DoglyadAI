---
name: mobile-module
description: Create a mobile application module according to Doglyad conventions. Scaffold an iOS SwiftUI and MVVM screen or bottom sheet with Screen, ScreenView, ViewModel, and Arguments types and register it in the router. Use when adding a mobile screen, bottom sheet, or navigation module.
---

# Create a mobile module

Create and fully connect a module so its structure and style match the existing application.

## Platforms

- **iOS:** Follow the procedure below.
- **Android:** Add an equivalent section when an Android project exists. Keep this skill concept cross-platform.

Detect the platform first. When the repository contains only iOS, proceed without asking an unnecessary platform question.

## Resolve before implementation

1. Choose a PascalCase module name without a suffix, such as `Profile` or `Statistics`.
2. Determine whether it is a full-screen `Screen` or a `BottomSheet`.
3. Define incoming data and callbacks; arguments may be empty.
4. Determine whether the module depends on repositories or managers from `DependencyContainer`, which affects `onInit()`.

## iOS: SwiftUI and MVVM

Create modules in `ios/Doglyad/Application/Module/<Name>/`. Register navigation in `ios/Doglyad/Application/Application/Router/RouteType.swift` and `RouterBuilder.swift`.

Before generating code, read `Module/Settings/Settings/` for a full-screen reference or `Module/Select/NeuralModel/` for a sheet reference. Treat the templates below as scaffolding only.

### Required conventions

- Make `*Screen` a SwiftUI view that only creates the view model and passes it to `*ScreenView`.
- Keep `*ScreenView` free of business and presentation logic. Build layout only with `DoglyadUI` components such as `DScreen`, `DBottomSheet`, `DListButtonCard`, `DButton`, `DText`, and `DTheme`.
- Mark `*ViewModel` with `@MainActor`, inherit from `DViewModel`, and keep all presentation logic there.
- Pass the entire `DependencyContainer` when the view model needs container dependencies.
- Never let view models communicate directly. Exchange module data only through closures supplied while constructing the destination view model.
- Let each module's view model control visibility for that module. Expose computed flags and methods such as `isSpeechButtonVisible` or `isSettingsAIVisible`; let `*ScreenView` branch only on its own view model.
- Use `@Published` for scalar state and `@NestedObservableObject` for nested observable controllers. Let the view own its view model with `@StateObject`.
- Use only `DoglyadNetwork` for networking and `DoglyadDatabase` for persistence.
- Use `LocalizedStringResource` values from `Localizable.xcstrings`. Add both English and Russian values for new keys.

### Full-screen module files

Create `<Name>Screen.swift`, `<Name>ScreenView.swift`, `<Name>ViewModel.swift`, and `<Name>ScreenArguments.swift`.

Create `<Name>ScreenArguments.swift`; leave the body empty when no arguments are required:

```swift
import Router

final class <Name>ScreenArguments: RouteArgumentsProtocol {
    // let value: SomeType
    // let onResult: (SomeType) -> Void
    // init(...) { ... }
}
```

Create `<Name>Screen.swift`:

```swift
import DoglyadUI
import Router
import SwiftUI

struct <Name>Screen: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    let arguments: <Name>ScreenArguments?

    var body: some View {
        <Name>ScreenView(
            viewModel: <Name>ViewModel(
                container: container,
                router: router
            )
        )
    }
}

#Preview {
    <Name>Screen(arguments: nil)
        .previewable()
}
```

Create `<Name>ViewModel.swift`:

```swift
import Foundation
import Handler
import Router
import SwiftUI

@MainActor
final class <Name>ViewModel: DViewModel {
    private let container: DependencyContainer
    private let router: DRouter

    init(
        container: DependencyContainer,
        router: DRouter
    ) {
        self.container = container
        self.router = router
        super.init()
    }

    // @Published var items: [Some] = []

    // Load data here. onAppear calls onInit only once.
    // override func onInit() {
    //     handle {
    //         await self.container.someRepository.getItems()
    //     } onMainSuccess: { items in
    //         self.items = items
    //     }
    // }

    func onTapBack() {
        router.pop()
    }
}
```

Create `<Name>ScreenView.swift`:

```swift
import DoglyadUI
import SwiftUI

struct <Name>ScreenView: View {
    @EnvironmentObject private var theme: DTheme
    private var size: DSize { theme.size }

    @StateObject var viewModel: <Name>ViewModel

    var body: some View {
        DScreen(
            title: .<nameLocalizedTitleKey>,
            onTapBack: viewModel.onTapBack
        ) { toolbarInset in
            ScrollView(showsIndicators: false) {
                VStack(spacing: size.s16) {
                    // Build the layout from DoglyadUI components.
                }
                .padding(size.s16)
                .padding(.top, toolbarInset)
                .padding(.bottom, size.s32)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .environmentObject(viewModel)
    }
}
```

### Register full-screen navigation

1. Add `case <name>` to `enum ScreenType` in `RouteType.swift`.
2. Add a branch to `build(route: RouteScreen<ScreenType>)` in `RouterBuilder.swift`:

```swift
case .<name>:
    AnyView(
        <Name>Screen(
            arguments: route.arguments as? <Name>ScreenArguments
        )
    )
```

Use `as!` only when arguments are mandatory, following `.conclusion`.

3. Navigate from another view model:

```swift
router.push(route: RouteScreen(type: .<name>))
router.push(
    route: RouteScreen(
        type: .<name>,
        arguments: <Name>ScreenArguments(...)
    )
)
```

### Bottom sheet variant

Create `<Name>BottomSheet.swift` and `<Name>Arguments.swift`. Sheets are often simple enough to omit separate view and view-model types; follow the nearest existing example.

```swift
import DoglyadUI
import Router
import SwiftUI

struct <Name>BottomSheet: View {
    @EnvironmentObject private var container: DependencyContainer
    @EnvironmentObject private var router: DRouter
    @EnvironmentObject private var theme: DTheme
    private var size: DSize { theme.size }

    let arguments: <Name>Arguments?

    var body: some View {
        DBottomSheet(
            title: .<nameLocalizedTitleKey>,
            fraction: 0.8
        ) { toolbarHeight in
            ScrollView(showsIndicators: false) {
                VStack(spacing: .zero) {
                    // Content
                }
                .padding(size.s16)
                .padding(.top, toolbarHeight)
            }
        }
    }
}

#Preview {
    <Name>BottomSheet(arguments: nil)
        .previewable()
}
```

Add `case <name>` to `SheetType` and handle it in `build(route: RouteSheet<SheetType>)`. Present it with `router.push(route: RouteSheet(type: .<name>, arguments: ...))` and close it with `router.dismissSheet()`.

## Finish

1. Add English and Russian localization values to `ios/Doglyad/Resources/Localizable.xcstrings`.
2. Rely on Xcode synchronized groups to discover new files; normally do not edit `project.pbxproj`. Confirm that new types compile.
3. Run `make format`.
4. Report the created files and router registration points.
