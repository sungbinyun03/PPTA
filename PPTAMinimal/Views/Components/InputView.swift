//
//  InputView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 1/20/25.
//

import SwiftUI

struct InputView: View {
    @Binding var text: String
    let title: String
    let placeholder: String
    var isSecureField = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(Color("primaryColor"))
                .font(.body)
            
            if isSecureField {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundStyle(.gray))
                    .padding()
                    .background(Color("backgroundGray"))
                    .foregroundStyle(Color.black)
                    .cornerRadius(8)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.gray))
                    .padding()
                    .background(Color("backgroundGray"))
                    .foregroundStyle(Color.black)
                    .cornerRadius(8)
            }
        }
    }
}

#Preview {
    InputView(text: .constant(""), title: "Email Address", placeholder: "name@example.com")
}
