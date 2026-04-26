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
                        ListRow(eachApp: eachApp, timeLimitSeconds: activityReport.timeLimitSeconds)
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
    var timeLimitSeconds: TimeInterval

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                if let token = eachApp.token {
                    if eachApp.displayName.isEmpty {
                        // Zero-activity app: system label renders both icon and name
                        Label(token)
                            .offset(x: -4)
                    } else {
                        Label(token)
                            .labelStyle(.iconOnly)
                            .offset(x: -4)
                    }
                }
                if !eachApp.displayName.isEmpty {
                    Text(eachApp.displayName)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(timeLimitSeconds > 0
                            ? "\(eachApp.duration.toString()) / \(timeLimitSeconds.toString())"
                            : eachApp.duration.toString())
                            .font(.headline)
                            .frame(minWidth: 52, alignment: .trailing)
                    }
                }
            }
            if timeLimitSeconds > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(.systemGray5))
                            .frame(height: 4)
                        Capsule()
                            .fill(Color.green)
                            .frame(
                                width: geo.size.width * min(eachApp.duration / timeLimitSeconds, 1.0),
                                height: 4
                            )
                    }
                }
                .frame(height: 4)
            }
        }
        .listRowBackground(Color.clear)
    }
}
