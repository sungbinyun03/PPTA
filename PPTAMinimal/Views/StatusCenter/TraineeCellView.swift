//
//  TraineeCellView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 14/10/25.
//

import SwiftUI

struct TraineeCellView: View {
    private var name: String
    private var status: TraineeStatus
    private var profilePicUrl: String?
    private var pressureLevel: PressureLevel

    var lockedByName: String? = nil
    var onRelease: (() -> Void)? = nil
    var onLock: (() -> Void)? = nil

    init(
        name: String,
        status: TraineeStatus,
        profilePicUrl: String? = nil,
        pressureLevel: PressureLevel = .off,
        lockedByName: String? = nil,
        onRelease: (() -> Void)? = nil,
        onLock: (() -> Void)? = nil
    ) {
        self.name = name
        self.status = status
        self.profilePicUrl = profilePicUrl
        self.pressureLevel = pressureLevel
        self.lockedByName = lockedByName
        self.onRelease = onRelease
        self.onLock = onLock
    }

    var body: some View {
        HStack {
            Group {
                if let profilePicUrl, let url = URL(string: profilePicUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image("google-icon").resizable().scaledToFill()
                        }
                    }
                } else {
                    Image("google-icon").resizable().scaledToFill()
                }
            }
                .frame(width: 65, height: 65)
                .clipShape(Circle())
                .overlay(alignment: .bottomTrailing) {
                    if status == .cutOff, let locker = lockedByName {
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
                        Text("Release")
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
        switch status {
        case .allClear: return .green
        case .attentionNeeded: return .orange
        case .cutOff: return .red
        case .noStatus: return .clear
        }
    }

    // MARK: - Buttons state and appearance
    private var canLock: Bool { status == .attentionNeeded }
    // Hardcore trainees cannot be remotely unlocked — the device blocks it.
    private var canRelease: Bool { status == .cutOff && pressureLevel != .hardcore }

    private var lockBackground: Color { canLock ? Color.orange : Color(.systemGray5) }
    private var lockTextColor: Color { canLock ? .white : Color(.gray) }
    private var releaseBackground: Color { canRelease ? Color("primaryButtonColor") : Color(.systemGray5) }
    private var releaseTextColor: Color { canRelease ? .white : Color(.gray) }
}

#Preview {
    TraineeCellView(name: "Peter Parker", status: .attentionNeeded, profilePicUrl: "peter_parker")
}
