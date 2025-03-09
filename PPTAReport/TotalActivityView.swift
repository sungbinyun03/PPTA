//
//  TotalActivityView.swift
//  PPTAReport
//
//  Created by Sungbin Yun on 1/27/25.
//

import SwiftUI
import FamilyControls

struct TotalActivityView: View {
    var activityReport: ActivityReport
    
    var body: some View {
        VStack(spacing: 4) {
            Spacer(minLength: 24)
//            Text("Total Screentime:")
//                .font(.callout)
//                .foregroundColor(.secondary)
//            Text(activityReport.totalDuration.toString())
//                .font(.largeTitle)
//                .bold()
//                .padding(.bottom, 8)
            List {
                Section {
                    ForEach(activityReport.apps) { eachApp in
                        ListRow(eachApp: eachApp)
                    }
                }
            }
            .scrollContentBackground(.hidden) // Hides the default background
            .background(Color.clear)
        }
    }
}

struct ListRow: View {
    var eachApp: AppDeviceActivity
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                if let token = eachApp.token {
                    Label(token)
                        .labelStyle(.iconOnly)
                        .offset(x: -4)
                }
                Text(eachApp.displayName)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
//                    HStack(spacing: 4) {
//                        Text("Pickups")
//                            .font(.footnote)
//                            .foregroundColor(.secondary)
//                            .frame(width: 72, alignment: .leading)
//                        Text("\(eachApp.numberOfPickups) Times")
//                            .font(.headline)
//                            .bold()
//                            .frame(minWidth: 52, alignment: .trailing)
//                    }
                    HStack(spacing: 4) {
//                        Text("Time")
//                            .font(.footnote)
//                            .foregroundColor(.secondary)
//                            .frame(width: 72, alignment: .leading)
                        Text(String(eachApp.duration.toString()))
                            .font(.headline)
//                            .bold()
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
    }
}
