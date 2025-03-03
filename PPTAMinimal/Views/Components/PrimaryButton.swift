//
//  PrimaryButton.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/3/25.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    var isDisabled: Bool = false
    var enabledBackground: Color = Color("primaryButtonColor")
    var disabledBackground: Color = .gray
    var cornerRadius: CGFloat = 10
    let action: () -> Void

    var body: some View {
        Button(action: {
            // Only execute action if button is not disabled
            if !isDisabled {
                action()
            }
        }) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isDisabled ? disabledBackground : enabledBackground)
                .cornerRadius(cornerRadius)
        }
        .disabled(isDisabled)
    }
}
