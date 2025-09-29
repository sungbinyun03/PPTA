//
//  DashboardViewModel.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 11/9/25.
//

import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    // Dependencies
    private var settings: UserSettingsManager
    private let calendar: Calendar
    private var cancellables = Set<AnyCancellable>()
    
    // Outputs for the view
    @Published private(set) var limitHours: Int = 0
    @Published private(set) var limitMinutes: Int = 0
    @Published private(set) var streakDays: Int? = nil

    init(settings: UserSettingsManager = .shared, calendar: Calendar = .current) {
        self.settings = settings
        self.calendar = calendar
        bind()
        refresh()
    }
    
    private func bind() {
        // Recompute streak when currentUser changes
        settings.$userSettings
            .map { userSettings in
                StreakCalculator.daysSince(start: userSettings.startDailyStreakDate, calendar: self.calendar)
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$streakDays)
        
        // Reflect threshold updates (hours)
              settings.$userSettings
                  .map(\.thresholdHour)
                  .removeDuplicates()
                  .assign(to: &$limitHours)

              // Reflect threshold updates (minutes)
              settings.$userSettings
                  .map(\.thresholdMinutes)
                  .removeDuplicates()
                  .assign(to: &$limitMinutes)
    }
    
    func refresh(now: Date = Date()) {
        limitHours = settings.userSettings.thresholdHour
        limitMinutes = settings.userSettings.thresholdMinutes
        streakDays = StreakCalculator.daysSince(start: settings.userSettings.startDailyStreakDate, now: now, calendar: calendar)
    }
}
