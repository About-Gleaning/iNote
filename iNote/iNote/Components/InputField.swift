import SwiftUI

struct InputField: View {
    @Binding var text: String
    var placeholder: String
    var focus: FocusState<Bool>.Binding? = nil
    var submitLabel: SubmitLabel = .done
    var autocorrectionDisabled: Bool = true
    var autocapitalization: TextInputAutocapitalization = .never
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        Group {
            let field = TextField(placeholder, text: $text)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(autocorrectionDisabled)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
                .alignmentGuide(.firstTextBaseline) { d in d[VerticalAlignment.center] }
                .padding(.vertical, 2)

            if let focus { field.focused(focus) } else { field }
        }
    }
}