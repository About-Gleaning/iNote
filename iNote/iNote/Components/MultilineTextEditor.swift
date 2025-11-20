import SwiftUI

struct MultilineTextEditor: View {
    @Binding var text: String
    var minHeight: CGFloat = 120
    var placeholder: String? = nil
    var focus: FocusState<Bool>.Binding? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            let editor = TextEditor(text: $text)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(AppColors.cardBackground)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.divider))

            if let focus { editor.focused(focus) } else { editor }

            if let placeholder, text.isEmpty {
                Text(placeholder)
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }
}