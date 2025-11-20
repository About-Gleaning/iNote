import SwiftUI
import UIKit

extension View {
    func keyboardDismissToolbar(_ title: String = "收起键盘", action: @escaping () -> Void = {}) -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(title) {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    action()
                }
            }
        }
    }
}