//
//  ContactsPickerView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 1/12/25.
//

import SwiftUI
import ContactsUI
import FirebaseFirestore


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
            let group = DispatchGroup()
            var newCoaches: [PeerCoach] = []
            
            for contact in contacts {
                group.enter()
                convertCNContactToPeerCoach(contact) { peerCoach in
                    newCoaches.append(peerCoach)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                print("All peer coaches processed: \(newCoaches)")
                UserSettingsManager.shared.loadSettings { currentSettings in
                    let updatedSettings = currentSettings
                    updatedSettings.peerCoaches.append(contentsOf: newCoaches)
                    
                    DispatchQueue.main.async {
                        UserSettingsManager.shared.saveSettings(updatedSettings)
                    }
           
                }
                DispatchQueue.main.async {
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
                
                
            }
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func convertCNContactToPeerCoach(_ contact: CNContact, completion: @escaping (PeerCoach) -> Void) {
            print("##### CONVERT CALL")
            let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
            let db = Firestore.firestore()
            db.collection("users").whereField("phoneNumber", isEqualTo: phone).getDocuments { snapshot, error in
                var token: String? = nil
                if let document = snapshot?.documents.first {
                    token = document.data()["fcmToken"] as? String
                }
                
                let peerCoach = PeerCoach(
                    givenName: contact.givenName,
                    familyName: contact.familyName,
                    phoneNumber: phone,
                    fcmToken: token
                )
                
                print("###### COACH : \(peerCoach)")
                completion(peerCoach)
            }
        }
    }
}
