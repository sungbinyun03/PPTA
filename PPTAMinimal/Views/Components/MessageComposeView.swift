//
//  MessageComposeView.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/20/25.
//

import SwiftUI
import MessageUI

/// SwiftUI wrapper around `MFMessageComposeViewController` (SMS/iMessage composer).
struct MessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    var onFinish: ((MessageComposeResult) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients
        controller.body = body
        print("MessageComposeView.makeUIViewController:")
        print("  recipients=\(recipients)")
        print("  body=\(body)")
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {
        // SwiftUI can present the sheet before state is fully propagated; keep the
        // controller in sync on updates so recipients/body reliably pre-fill.
        print("MessageComposeView.updateUIViewController:")
        print("  incoming recipients=\(recipients)")
        print("  incoming body=\(body)")
        print("  controller.recipients(before)=\(uiViewController.recipients ?? [])")
        print("  controller.body(before)=\(uiViewController.body ?? "")")
        if uiViewController.recipients != recipients {
            uiViewController.recipients = recipients
        }
        if uiViewController.body != body {
            uiViewController.body = body
        }
        print("  controller.recipients(after)=\(uiViewController.recipients ?? [])")
        print("  controller.body(after)=\(uiViewController.body ?? "")")
    }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let parent: MessageComposeView

        init(parent: MessageComposeView) {
            self.parent = parent
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            parent.onFinish?(result)
            controller.dismiss(animated: true)
        }
    }
}


