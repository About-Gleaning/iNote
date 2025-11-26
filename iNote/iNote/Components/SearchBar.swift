import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var onSubmit: (() -> Void)? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.secondaryText)
                
                InputField(text: $text, placeholder: "搜索笔记", focus: focus, submitLabel: .search, autocorrectionDisabled: false, autocapitalization: .never) {
                    onSubmit?()
                }
                
                if !text.isEmpty {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
            }
            .padding(12)
            .background(AppColors.cardBackground)
            .cornerRadius(12)
            
            if focus.wrappedValue {
                Button("取消") {
                    text = ""
                    focus.wrappedValue = false
                    onCancel?()
                }
                .foregroundColor(AppColors.primaryText)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focus.wrappedValue)
    }
}