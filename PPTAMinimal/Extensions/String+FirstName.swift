//
//  String+FirstName.swift
//  PPTAMinimal
//
//  Shortens display names for notifications.
//

import Foundation

extension String {
    /// The first word of a display name. Notifications read cleaner with "Damien" than
    /// "Damien Koh" — especially in titles. Falls back to the whole string for single-word
    /// names, and to itself (empty) if there's nothing to split.
    var firstNameOnly: String {
        split(separator: " ").first.map(String.init) ?? self
    }
}
