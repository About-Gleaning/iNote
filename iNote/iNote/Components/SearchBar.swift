import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.secondaryText)
            InputField(text: $text, placeholder: "搜索笔记", focus: focus, submitLabel: .search, autocorrectionDisabled: false, autocapitalization: .never) {
                focus.wrappedValue = false
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(12)
    }
}