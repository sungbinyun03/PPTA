//
//  CloudRunHTTPClient.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import Foundation
import FirebaseAuth

final class CloudRunHTTPClient {
    enum ClientError: LocalizedError {
        case notSignedIn
        case invalidURL
        case nonHTTPResponse
        case serverError(status: Int, body: String?)
        case decodeError

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "You must be signed in."
            case .invalidURL: return "Invalid server URL."
            case .nonHTTPResponse: return "Invalid server response."
            case .serverError(let status, let body):
                if let body, !body.isEmpty {
                    return "Server error (\(status)): \(body)"
                }
                return "Server error (\(status))."
            case .decodeError: return "Malformed server response."
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    /// POST JSON with `Authorization: Bearer <Firebase ID token>`.
    func postJSON<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        guard let user = Auth.auth().currentUser else { throw ClientError.notSignedIn }
        let token = try await user.getIDToken()

        // If caller passes an empty path, hit the base URL exactly (important when baseURL already
        // contains the function route like `/roleRequests`).
        let url: URL = path.isEmpty ? baseURL : baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw ClientError.nonHTTPResponse }
        guard (200..<300).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8)
            throw ClientError.serverError(status: http.statusCode, body: raw)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ClientError.decodeError
        }
    }

    /// POST JSON and ignore response body (expects 2xx).
    func postJSON(_ path: String, body: [String: Any]) async throws {
        struct Empty: Decodable {}
        _ = try await postJSON(path, body: body) as Empty
    }
}


