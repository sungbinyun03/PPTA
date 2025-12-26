//
//  ShareSheet.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/20/25.
//

import SwiftUI
import UIKit

/// SwiftUI wrapper around `UIActivityViewController`.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // no-op
    }
}


