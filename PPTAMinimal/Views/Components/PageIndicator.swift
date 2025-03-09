//
//  PageIndicator.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/3/25.
//

import SwiftUI

struct PageIndicator: View {
    var page: Int = 0
    var length: Int = 6
    
    var body: some View {
        HStack {
            ForEach(0..<page) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
            
            Circle()
                .fill(Color("primaryColor"))
                .frame(width: 8, height: 8)
            
            ForEach(page+1..<length) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

#Preview {
    PageIndicator()
}
