//
//  FriendsContactsPickerView.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/20/25.
//

import SwiftUI
import ContactsUI

/// SwiftUI wrapper around `CNContactPickerViewController` for selecting contacts to add as friends.
struct FriendsContactsPickerView: UIViewControllerRepresentable {
    let onSelect: ([CNContact]) -> Void
    var onCancel: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator

        // Only enable contacts that have at least one phone number.
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // no-op
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        private let parent: FriendsContactsPickerView

        init(parent: FriendsContactsPickerView) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onSelect(contacts)
            parent.dismiss()
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.onCancel?()
            parent.dismiss()
        }
    }
}


