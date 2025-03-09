//
//  LimitSettingsView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//

import SwiftUI
import FamilyControls

struct LimitSettingsView: View {
    @State private var isPickerPresented = false
    @State private var selection = FamilyActivitySelection()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Limit Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Set Your Screen Time Limits: Choose how much time you'd like to spend on the app each day.")
                    .font(.subheadline)

                // App Time Limits Section
                appTimeLimitsSection

                Button(action: { isPickerPresented = true }) {
                    Text("Add New")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)

                // Illustration at Bottom
                Image(systemName: "person.3.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .padding(.top, 30)
            }
            .padding()
        }
    }

    private var appTimeLimitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App Time Limits")
                .font(.headline)

            ForEach(Array(selection.applicationTokens), id: \.self) { token in
                HStack {
                    Label(token) // Displays App Name
                    Spacer()
                    Text("1h") // Placeholder for Time Limit
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke())
            }
        }
    }
}
