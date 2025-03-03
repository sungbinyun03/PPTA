//
//  FindFriendsView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI
import Contacts
import ContactsUI

struct FindFriendsView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var viewModel: AuthViewModel
    @ObservedObject var userSettingsManager = UserSettingsManager.shared
    @State private var showingContactPicker = false
    @State private var selectedContacts: [CNContact] = []
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Find Friends")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Handshake icon or similar
            Image(systemName: "person.2.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                .padding()
            
            Text("John Smith")
                .font(.headline)
            
            Text("Jane Doe")
                .font(.headline)
            
            Text("Not here? Invite")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: {
                showingContactPicker = true
            }) {
                Text("Select Contacts")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .cornerRadius(10)
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactsPickerView(selectedContacts: $selectedContacts)
            }
            
            Button(action: {
                coordinator.advance()
            }) {
                Text("Let's Begin!")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .cornerRadius(10)
            }
            
            // Page indicator
            HStack {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                
                Circle()
                    .fill(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .frame(width: 8, height: 8)
            }
            .padding(.bottom, 20)
        }
        .padding()
    }
}
