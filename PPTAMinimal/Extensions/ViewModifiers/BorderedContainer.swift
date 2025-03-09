//
//  BorderContainer.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/3/25.
//

import SwiftUI

struct BorderedContainer: ViewModifier {
    var width: CGFloat = 370
    var cornerRadius: CGFloat = 15
    var strokeColor: Color = .black
    var strokeLineWidth: CGFloat = 1
    var backgroundColor: Color = .white
    
    func body(content: Content) -> some View {
        content
            .padding(10)
            .frame(width: width)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(strokeColor, lineWidth: strokeLineWidth)
            )
    }
}

extension View {
    func borderedContainer(width: CGFloat = 370,
                           cornerRadius: CGFloat = 15,
                           strokeColor: Color = .black,
                           strokeLineWidth: CGFloat = 1,
                           backgroundColor: Color = .white) -> some View {
        self.modifier(BorderedContainer(width: width,
                                        cornerRadius: cornerRadius,
                                        strokeColor: strokeColor,
                                        strokeLineWidth: strokeLineWidth,
                                        backgroundColor: backgroundColor))
    }
}
