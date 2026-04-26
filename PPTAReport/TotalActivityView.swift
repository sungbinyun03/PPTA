//
//  TotalActivityView.swift
//  PPTAReport
//
//  Created by Sungbin Yun on 1/27/25.
//

import SwiftUI
import FamilyControls

// MARK: - App Color Helper

extension Color {
    static func appPrimary(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 141/255, green: 147/255, blue: 136/255)
            : Color(red: 68/255, green: 86/255, blue: 46/255)
    }
}

// MARK: - Main View

struct TotalActivityView: View {
    var activityReport: ActivityReport
    @Environment(\.colorScheme) var colorScheme

    private var primary: Color { .appPrimary(colorScheme) }

    private var maxDuration: TimeInterval {
        activityReport.apps.map(\.duration).max() ?? 1
    }

    private var sortedApps: [AppDeviceActivity] {
        activityReport.apps.sorted { $0.duration > $1.duration }
    }

    private var hasHourlyData: Bool {
        activityReport.hourlyBuckets.contains { $0.duration > 0 }
    }

    var body: some View {
        List {
            Section {
                ProgressRingView(
                    totalDuration: activityReport.totalDuration,
                    limitMinutes: activityReport.limitMinutes,
                    primary: primary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if hasHourlyData {
                Section {
                    HourlyBarChart(buckets: activityReport.hourlyBuckets, primary: primary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    ReportSectionHeader("HOURLY BREAKDOWN", primary: primary)
                }
            }

            if !sortedApps.isEmpty {
                Section {
                    ForEach(sortedApps) { app in
                        AppActivityRow(app: app, maxDuration: maxDuration, primary: primary)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                } header: {
                    ReportSectionHeader("YOUR APPS", primary: primary)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Progress Ring

struct ProgressRingView: View {
    let totalDuration: TimeInterval
    let limitMinutes: Int
    let primary: Color

    private var progress: Double {
        guard limitMinutes > 0 else { return 0 }
        return min(totalDuration / (Double(limitMinutes) * 60.0), 1.0)
    }

    private var ringColor: Color {
        switch progress {
        case ..<0.7: return primary
        case ..<0.9: return .orange
        default: return Color(red: 0.85, green: 0.2, blue: 0.2)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(primary.opacity(0.12), lineWidth: 14)
                    .frame(width: 130, height: 130)

                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 3) {
                    Text(totalDuration.toShortString())
                        .font(.custom("BambiBold", size: 26))
                        .foregroundColor(ringColor)
                    if limitMinutes > 0 {
                        Text("of \(TimeInterval(Double(limitMinutes) * 60).toShortString())")
                            .font(.custom("Satoshi-Variable", size: 12))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Text("TODAY'S SCREEN TIME")
                .font(.custom("Satoshi-Variable", size: 11))
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundColor(primary.opacity(0.6))
        }
    }
}

// MARK: - Hourly Bar Chart

struct HourlyBarChart: View {
    let buckets: [HourlyBucket]
    let primary: Color

    private var maxDuration: TimeInterval {
        buckets.map(\.duration).max() ?? 1
    }

    private var currentHour: Int {
        Calendar.current.component(.hour, from: .now)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(buckets) { bucket in
                    let proportion = maxDuration > 0 ? CGFloat(bucket.duration / maxDuration) : 0
                    let isNow = bucket.id == currentHour
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isNow ? primary : primary.opacity(0.25))
                        .frame(height: max(proportion * 52, bucket.duration > 0 ? 3 : 0))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 52)

            HStack {
                Text("12a").frame(maxWidth: .infinity, alignment: .leading)
                Text("6a").frame(maxWidth: .infinity)
                Text("12p").frame(maxWidth: .infinity)
                Text("6p").frame(maxWidth: .infinity)
                Text("11p").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.custom("Satoshi-Variable", size: 10))
            .fontWeight(.medium)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - App Row

struct AppActivityRow: View {
    let app: AppDeviceActivity
    let maxDuration: TimeInterval
    let primary: Color

    private var barFraction: CGFloat {
        guard maxDuration > 0 else { return 0 }
        return CGFloat(app.duration / maxDuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                if let token = app.token {
                    if app.displayName.isEmpty {
                        Label(token)
                            .offset(x: -4)
                    } else {
                        Label(token)
                            .labelStyle(.iconOnly)
                            .offset(x: -4)
                    }
                }
                if !app.displayName.isEmpty {
                    Text(app.displayName)
                        .font(.custom("Satoshi-Variable", size: 15))
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                Spacer()
                Text(app.duration.toString())
                    .font(.custom("Satoshi-Variable", size: 15))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundColor(primary)
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(primary.opacity(0.1))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(primary.opacity(0.55))
                    .scaleEffect(x: barFraction, y: 1.0, anchor: .leading)
            }
            .frame(height: 5)

            if app.numberOfNotifications > 0 || app.numberOfPickups > 0 {
                HStack(spacing: 10) {
                    if app.numberOfNotifications > 0 {
                        Label {
                            Text("\(app.numberOfNotifications) notifications")
                        } icon: {
                            Image(systemName: "bell.fill")
                        }
                    }
                    if app.numberOfPickups > 0 {
                        Label {
                            Text("\(app.numberOfPickups) pickups")
                        } icon: {
                            Image(systemName: "hand.point.up.fill")
                        }
                    }
                }
                .font(.custom("Satoshi-Variable", size: 11))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Section Header

struct ReportSectionHeader: View {
    let title: String
    let primary: Color

    init(_ title: String, primary: Color) {
        self.title = title
        self.primary = primary
    }

    var body: some View {
        Text(title)
            .font(.custom("Satoshi-Variable", size: 11))
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundColor(primary.opacity(0.6))
            .textCase(nil)
    }
}
