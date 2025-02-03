//
//  ContactsPickerView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 1/12/25.
//

import SwiftUI
import ContactsUI

struct ContactsPickerView: UIViewControllerRepresentable {
    
    @Environment(\.presentationMode) var presentationMode
    @Binding var selectedContacts: [CNContact]
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // BOILER
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactsPickerView
        
        init(_ parent: ContactsPickerView) {
            self.parent = parent
        }

        // Multiple contact selection
         func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.selectedContacts.append(contentsOf: contacts)
            let newCoaches = contacts.map { convertCNContactToPeerCoach($0) }
            
            UserSettingsManager.shared.loadSettings { currentSettings in
                 var updatedSettings = currentSettings
                 updatedSettings.peerCoaches.append(contentsOf: newCoaches)
                 UserSettingsManager.shared.saveSettings(updatedSettings)
            }
            
            parent.presentationMode.wrappedValue.dismiss()
         }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func convertCNContactToPeerCoach(_ contact: CNContact) -> PeerCoach {
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            return PeerCoach(
                givenName: contact.givenName,
                familyName: contact.familyName,
                phoneNumber: phone
            )
        }
    }
}
