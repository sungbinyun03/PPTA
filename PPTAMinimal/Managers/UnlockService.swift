//
//  UnlockService.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 5/29/25.
//


import Foundation
import CryptoKit

enum UnlockService {
    private static let baseURL = URL(string:"https://unlockapp-iy4j75c7pq-uc.a.run.app")!
    private static let secretData =
        Data("a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e".utf8)

    static func makeUnlockURL(childUID: String,
                              coachUID: String) -> URL? {

        let ts  = Int(Date().timeIntervalSince1970)
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
        return comps.url
    }
}
