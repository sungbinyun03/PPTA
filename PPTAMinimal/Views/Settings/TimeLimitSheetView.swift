//
//  TimeLimitSheetView.swift
//  PPTAMinimal
//
//  Sheet to pick hours/minutes for the daily limit. Updates **draft** bindings only
//  when the user taps the checkmark — same pattern as `FamilyActivityPicker` +
//  App Limits “Save Settings”. Does not persist to Firestore by itself.
//

import SwiftUI

struct TimeLimitSheetView: View {
    @Environment(\.dismiss) private var dismiss

    /// Parent-owned draft; committed only when the user taps the checkmark (then dismissed).
    @Binding var draftHours: Int
    @Binding var draftMinutes: Int

    /// Local wheels so Cancel leaves the parent draft unchanged.
    @State private var hours: Int = 0
    @State private var minutes: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Set your daily screen time limit.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    Text("Daily Limit")
                        .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                        .padding(.top, 10)

                    HStack(spacing: 12) {
                        VStack {
                            Picker("Hours", selection: $hours) {
                                ForEach(0...23, id: \.self) { hour in
                                    Text(String(format: "%02d", hour))
                                        .tag(hour)
                                }
                            }
                            .frame(width: 60, height: 120)
                            .clipped()
                            .pickerStyle(.wheel)
                            Text("Hours")
                                .font(.footnote)
                        }

                        VStack {
                            Picker("Minutes", selection: $minutes) {
                                ForEach(0...59, id: \.self) { min in
                                    Text(String(format: "%02d", min))
                                        .tag(min)
                                }
                            }
                            .frame(width: 60, height: 120)
                            .clipped()
                            .pickerStyle(.wheel)
                            Text("Minutes")
                                .font(.footnote)
                        }
                    }
                }
                .frame(maxWidth: 340)
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(red: 0.247, green: 0.266, blue: 0.211), lineWidth: 4)
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Time Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                            .frame(width: 39, height: 39)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        draftHours = hours
                        draftMinutes = minutes
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Confirm selection")
                }
            }
            .onAppear {
                hours = draftHours
                minutes = draftMinutes
            }
        }
    }
}

#Preview {
    TimeLimitSheetView(draftHours: .constant(1), draftMinutes: .constant(30))
}
