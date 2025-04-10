//
//  SettingsView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var selectedTab = "Settings"
    
    var body: some View {
        NavigationView {
            VStack(spacing: 10) {
                profileSection
                inviteBanner
                tabSelector
                settingsContent
            }
            .padding()
        }
    }
    
    private var profileSection: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .strokeBorder(Color(red: 0.266, green: 0.337, blue: 0.180), lineWidth: 6)
                    .frame(width: 130, height: 130)
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.gray)
            }
            .overlay(
                Text("Change Photo")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 14))
                    .padding(4)
                    .background(Color(red: 0.4392, green: 0.4784, blue: 0.3843).opacity(1.0))
                    .clipShape(Capsule())
                    .offset(y: 60)
            )
            VStack(alignment: .leading, spacing: 12 ){
                Text(viewModel.currentUser?.name ?? "User")
                    .font(.custom("BambiBold", size: 22))
                    .fontWeight(.bold)
                
                Button(action: {}) {
                    HStack(alignment: .center, spacing: 4){
                        Text("Edit your profile")
                            .font(.custom("SatoshiVariable-Bold_Light", size: 14))
                            
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(6)
                    .background(Color(red: 0.521, green: 0.6509, blue: 0.423).opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .offset(x: -20)
        .padding(.bottom)
    }
    
    private var inviteBanner: some View {
        HStack(alignment: .center) {
            Image(systemName: "person.3.fill")
                .foregroundColor(.gray)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading) {
                Text("Don't let your friends scroll endlessly alone!")
                    .font(.custom("SatoshiVariable-Bold_Bold", size: 12))
                    .lineLimit(1)
                    .fontWeight(.bold)
                Text("Invite 3 friends to unlock full features and hold each other accountable—because self-control is a team sport!")
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
    }
    
    private var tabSelector: some View {
            HStack {
                ForEach(["Settings", "Friends"], id: \.self) { tab in
                    VStack {
                        Text(tab)
                            .fontWeight(selectedTab == tab ? .bold : .regular)
                            .foregroundColor(selectedTab == tab ? .black : .gray)
                            .onTapGesture {
                                selectedTab = tab
                            }
                        
                        if selectedTab == tab {
                            Rectangle()
                                .frame(height: 3)
                                .foregroundColor(.black)
                                .cornerRadius(2)
                        } else {
                            Rectangle()
                                .frame(height: 3)
                                .foregroundColor(.clear)
                        }
                    }
                    .frame(maxWidth: 120)
                }
            }
            .padding(.vertical)
            .frame(width: 250)
        }
    
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if selectedTab == "Settings" {
                NavigationLink(destination: AppSelectView()) {
                    settingsRow(icon: "app.badge", text: "Monitored Apps")
                }
                NavigationLink(destination: LimitSettingsView()) {
                    settingsRow(icon: "clock", text: "Limit Settings")
                }
                settingsRow(icon: "lock.shield", text: "Security")
                settingsRow(icon: "questionmark.circle", text: "Support")
            } else {
                Text("Friends List Coming Soon")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func settingsRow(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 30)
            Text(text)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
//        .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 1))
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthViewModel())
    }
}
