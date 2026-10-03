//
//  UnlockService.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 5/29/25.
//


import Foundation
import CryptoKit

enum UnlockService {
    private static let unlockBaseURL = URL(string:"https://unlockapp-iy4j75c7pq-uc.a.run.app")!
    /// Deployed lock endpoint URL (same query-signature contract as unlock).
    private static let lockBaseURL = URL(string:"https://lockapp-538124351649.us-central1.run.app")!
    private static let secretData =
        Data("a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e".utf8)

    static func makeUnlockURL(childUID: String,
                              coachUID: String) -> URL? {
        makeSignedURL(baseURL: unlockBaseURL, childUID: childUID, coachUID: coachUID)
    }

    /// - Parameter message: optional note for the trainee. Cleaned here, and added as an unsigned `msg`
    ///   query item after signing, so the signature is identical with or without it.
    static func makeLockURL(childUID: String,
                            coachUID: String,
                            message: String? = nil,
                            now: Date = Date()) -> URL? {
        makeSignedURL(baseURL: lockBaseURL, childUID: childUID, coachUID: coachUID,
                      message: message, now: now)
    }

    private static func makeSignedURL(baseURL: URL,
                                      childUID: String,
                                      coachUID: String,
                                      message: String? = nil,
                                      now: Date = Date()) -> URL? {
        let ts  = Int(now.timeIntervalSince1970)
        let msg = "\(childUID)|\(coachUID)|\(ts)"
        let key = SymmetricKey(data: secretData)
        let sig = HMAC<SHA256>
            .authenticationCode(for: msg.data(using: .utf8)!, using: key)
            .map { String(format: "%02x", $0) }
            .joined()

        var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            .init(name: "uid",   value: childUID),
            .init(name: "coach", value: coachUID),
            .init(name: "ts",    value: "\(ts)"),
            .init(name: "sig",   value: sig)
        ]
        if let message = ActionMessage.clean(message) {
            comps.queryItems?.append(.init(name: "msg", value: message))
        }
        return comps.url
    }
}
