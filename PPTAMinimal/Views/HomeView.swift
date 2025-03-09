//
//  HomeView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @ObservedObject var userSettingsManager = UserSettingsManager.shared
    @State private var isReportViewPresented = false

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                ProfileView()
                weeklyStatsSection
                reportSection
                peerCoachesSection
            }
            .padding(.top, 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarHidden(true)
        }
        
        
    }

    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly stats")
                .font(.custom("SatoshiVariable-Bold_Light", size: 20))

            VStack(spacing: 10) {
                HStack (spacing: 14){
                    Button("Daily Focus Average") {}
                    Button("Daily Focus Average") {}
                }
                .buttonStyle(StatButtonStyle())

                HStack (spacing: 14) {
                    Button("Time over limit") {}
                    Button("More Text") {}
                }
                .buttonStyle(StatButtonStyle())
            }
        }
    }

    private var reportSection: some View {
        VStack {
            Button(action: { isReportViewPresented.toggle() }) {
                VStack {
                    Text("Daily Screen Time")
                        .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                        .padding(.top, 5)
                        .padding(.bottom, 5)

                    ScrollView {
                        ReportView(isMonitoring: false)
                            .frame(minHeight: 200, maxHeight: 259)
                    }
                    .frame(height: 259)
                }
                .padding(.vertical, 10)
                .frame(width: 333)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(red: 0.247, green: 0.266, blue: 0.211), lineWidth: 4)
                )
            }
        }
        .sheet(isPresented: $isReportViewPresented) {
            ReportView(isMonitoring: false)
        }
    }

    private var peerCoachesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Peer Coaches")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(userSettingsManager.userSettings.peerCoaches, id: \.id) { coach in
                        Circle()
                            .fill(Color.green) // ✅ Replace with actual coach image
                            .frame(width: 50, height: 50)
                    }
                }
            }
        }
    }
}

// MARK: - Button Style
struct StatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: 160, minHeight: 90)
            .background(Color(red: 0.4392, green: 0.4784, blue: 0.3843))
            .foregroundColor(.white)
            .cornerRadius(15)
    }
}
