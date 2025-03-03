//
//  AppleSignInButton.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/3/25.
//

import SwiftUI
import AuthenticationServices

struct AppleSignInButton: UIViewControllerRepresentable {
    typealias UIViewControllerType = UIViewController
    
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIViewController {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        viewModel.handleSignInWithAppleRequest(request)
        
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = context.coordinator
        controller.presentationContextProvider = context.coordinator
        controller.performRequests()
        
        // Return an empty view controller since ASAuthorizationController
        // presents itself
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let parent: AppleSignInButton
        
        init(_ parent: AppleSignInButton) {
            self.parent = parent
        }
        
        // MARK: - ASAuthorizationControllerDelegate
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            parent.viewModel.handleSignInWithAppleCompletion(.success(authorization))
            
            // Dismiss the hosting view controller if it was presented modally
            DispatchQueue.main.async {
                self.dismissHostingController()
            }
        }
        
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            parent.viewModel.handleSignInWithAppleCompletion(.failure(error))
            
            // Dismiss the hosting view controller if it was presented modally
            DispatchQueue.main.async {
                self.dismissHostingController()
            }
        }
        
        // Helper to dismiss the hosting controller
        private func dismissHostingController() {
            // This will dismiss the view controller that's hosting the AppleSignInButton
            if let hostingController = UIApplication.shared.windows.first?.rootViewController?.presentedViewController {
                hostingController.dismiss(animated: true)
            }
        }
        
        // MARK: - ASAuthorizationControllerPresentationContextProviding
        
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            // Get the window for presentation
            let scenes = UIApplication.shared.connectedScenes
            let windowScene = scenes.first as? UIWindowScene
            let window = windowScene?.windows.first
            return window ?? UIWindow()
        }
    }
}
