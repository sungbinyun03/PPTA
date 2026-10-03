//
//  ActionMessageField.swift
//  PPTAMinimal
//
//  Optional short note field (Instagram-notes feel) for a lock or a snooze request.
//

import SwiftUI

struct ActionMessageField: View {
    @Binding var text: String
    var placeholder = "Add a note (optional)"

    private var count: Int { text.count }

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.gray))
                .submitLabel(.done)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color("backgroundGray"))
                .foregroundStyle(Color.black)
                .clipShape(Capsule())
                .onChange(of: text) { _, newValue in
                    // Plain text, single line: cap at maxLength Characters and flatten newlines.
                    // Not ActionMessage.clean, which would eat the space the user is mid-typing.
                    let flattened = newValue.replacingOccurrences(of: "\n", with: " ")
                    let capped = String(flattened.prefix(ActionMessage.maxLength))
                    if capped != newValue { text = capped }
                }

            Text("\(count)/\(ActionMessage.maxLength)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(count >= ActionMessage.maxLength ? Color("primaryColor") : Color.secondary)
                .padding(.trailing, 8)
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var text = ""
        var body: some View {
            ActionMessageField(text: $text)
                .padding(24)
        }
    }
    return Demo()
}
