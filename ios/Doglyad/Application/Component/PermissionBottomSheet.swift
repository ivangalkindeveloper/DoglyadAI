import DoglyadUI
import Foundation
import SwiftUI

struct PermissionBottomSheet: DView {
    @EnvironmentObject var theme: DTheme

    let title: LocalizedStringResource
    let description: LocalizedStringResource

    var body: some View {
        DBottomSheet(
            title: title
        ) { toolbarHeight, _ in
            VStack(
                spacing: .zero
            ) {
                DText(description)
                    .dStyle(
                        font: typography.textSmall,
                        alignment: .center
                    )
                    .padding(.bottom, size.s32)
                DButton(
                    title: .buttonOpenSettings,
                    action: UIApplication.openSettings
                )
                .dStyle(.primaryButton)
            }
            .padding(size.s16)
            .padding(.top, toolbarHeight)
        }
    }
}
