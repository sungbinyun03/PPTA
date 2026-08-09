//
//  TraineeCellView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 14/10/25.
//

// ============================================================
// ⚠️  DEAD CODE — STATUS CENTER TAB REMOVED
// ============================================================
// This cell was only used inside StatusCenterView, which is no
// longer in the tab bar. Nothing in the active app references
// TraineeCellView. Safe to delete.
// ============================================================

import SwiftUI

struct TraineeCellView: View {
    private var name: String
    private var status: TraineeStatus
    private var profilePicUrl: String?

    var lockedByName: String? = nil
    var onRelease: (() -> Void)? = nil
    var onLock: (() -> Void)? = nil

    init(
        name: String,
        status: TraineeStatus,
        profilePicUrl: String? = nil,
        lockedByName: String? = nil,
        onRelease: (() -> Void)? = nil,
        onLock: (() -> Void)? = nil
    ) {
        self.name = name
        self.status = status
        self.profilePicUrl = profilePicUrl
        self.lockedByName = lockedByName
        self.onRelease = onRelease
        self.onLock = onLock
    }

    var body: some View {
        HStack {
            InitialsProfilePicView(name: name, profilePicUrl: profilePicUrl, size: 65)
                .overlay(alignment: .bottomTrailing) {
                    if (status == .cutOff || status == .snoozedLock), let locker = lockedByName {
                        let parts = locker.split(separator: " ")
                        let initials = parts.prefix(2)
                            .compactMap { $0.first }
                            .map(String.init)
                            .joined()
                            .uppercased()
                        Text(initials)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.orange)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                            .offset(x: 2, y: 2)
                    }
                }
            VStack(spacing: 12) {
                // Top row: avatar + name + small status dot
                HStack(alignment: .center, spacing: 12) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 16, height: 16)
                }
                
                // Bottom row: buttons
                HStack(spacing: 10) {
                    Button(action: { if canLock { onLock?() } }) {
                        Text("Lock")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(lockTextColor)
                            .background(lockBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(!canLock)

                    Button(action: { if canRelease { onRelease?() } }) {
                        Text("Snooze Lock (10 min)")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(releaseTextColor)
                            .background(releaseBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .disabled(!canRelease)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Status mapping
    private var statusDotColor: Color {
        status.ringColor ?? .clear
    }

    // MARK: - Buttons state and appearance
    private var canLock: Bool { status == .attentionNeeded }
    private var canRelease: Bool { status == .cutOff }

    private var lockBackground: Color { canLock ? Color.orange : Color(.systemGray5) }
    private var lockTextColor: Color { canLock ? .white : Color(.gray) }
    private var releaseBackground: Color { canRelease ? Color("primaryButtonColor") : Color(.systemGray5) }
    private var releaseTextColor: Color { canRelease ? .white : Color(.gray) }
}

#Preview {
    TraineeCellView(name: "Peter Parker", status: .attentionNeeded, profilePicUrl: "peter_parker")
}
