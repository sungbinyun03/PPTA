//
//  StreakCalculator.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 10/9/25.
//

import Foundation
/// Calculates day-based streaks normalized to calendar days.
/// /// Defaults to exclusive counting (0 if started today).
enum StreakCalculator {
    /// Returns the number of full calendar days from `start` to `now`.
    /// - Parameters:
    ///   - start: The streak start date (nil => 0).
    ///   - now: The reference date (default: current time).
    ///   - calendar: Calendar used for day boundaries (default: .current).
    ///   - inclusive: If true, counts today as day 1 (adds +1 when start <= today).
    static func daysSince(
        start: Date?,
        now: Date = Date(),
        calendar: Calendar = .current,
        inclusive: Bool = false
    ) -> Int {
        guard let start else { return 0 }
        let startDay = calendar.startOfDay(for: start)
        let today = calendar.startOfDay(for: now)
        let raw = calendar.dateComponents([.day], from: startDay, to: today).day ?? 0
        let base = max(0, raw)
        return inclusive ? base + 1 : base
    }
}
