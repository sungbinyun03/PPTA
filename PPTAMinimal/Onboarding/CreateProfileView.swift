//
//  CreateProfileView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI

struct CreateProfileView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var displayName: String = ""
    @State private var selectedTags: [String] = []
    @State private var availableTags = ["Studying Up", "Daily Reading", "Work", "One more", "Fitness"]
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Create Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Profile image placeholder
            Circle()
                .stroke(Color.gray, lineWidth: 1)
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color.gray.opacity(0.5))
                        .padding(20)
                )
            
            // Display name field
            VStack(alignment: .leading) {
                Text("Display Name")
                    .font(.headline)
                TextField("Display Name", text: $displayName)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }
            
            // Focus areas
            VStack(alignment: .leading) {
                Text("Focus Areas")
                    .font(.headline)
                
                // Tag grid
                FlowLayout(spacing: 10) {
                    ForEach(availableTags, id: \.self) { tag in
                        TagView(tag: tag, isSelected: selectedTags.contains(tag)) {
                            if selectedTags.contains(tag) {
                                selectedTags.removeAll { $0 == tag }
                            } else {
                                selectedTags.append(tag)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                if !displayName.isEmpty {
                    // Update user profile
                    Task {
                        await viewModel.updateUserDisplayName(displayName: displayName)
                        coordinator.advance()
                    }
                }
            }) {
                Text("Next")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(displayName.isEmpty ? Color.gray : Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .cornerRadius(10)
            }
            .disabled(displayName.isEmpty)
            
            // Page indicator
            HStack {
                ForEach(0..<2) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                
                Circle()
                    .fill(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .frame(width: 8, height: 8)
                
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
        }
        .padding()
    }
}

// Helper Views
struct TagView: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)) : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .black)
                .cornerRadius(16)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var height: CGFloat = 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
            height = max(height, y + maxHeight)
        }
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let width = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var maxHeight: CGFloat = 0
        
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += maxHeight + spacing
                maxHeight = 0
            }
            
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
        }
    }
}
