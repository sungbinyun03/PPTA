//
//  LegalLinks.swift
//  PPTAMinimal
//
//  One place for the hosted legal document URLs, so the login screen, Settings, and anywhere
//  else that links out all point at the same place.
//

import Foundation

enum LegalLinks {
    /// Source document lives at `docs/privacy-policy.md`; this is the published copy.
    ///
    /// NOTE: an `/edit` Google Docs link opens the *editor*, which on iOS bounces into the Google
    /// Docs app or a heavy web editor and shows a "Request access" wall to anyone the doc isn't
    /// shared with. Before submitting, swap this for File → Share → Publish to the web (a
    /// `/pub` URL), which renders as an ordinary public page.
    static let privacyPolicy =
        "https://docs.google.com/document/d/1Oc-GMgzHnEnlvRogCIVtFVjVORvgfXkGtz2Y2zYwHdQ/edit?usp=sharing"

    /// `nil` when the string above isn't a usable URL, so callers can hide the link
    /// rather than render something that does nothing when tapped.
    static var privacyPolicyURL: URL? { URL(string: privacyPolicy) }
}
