import XCTest
@testable import CodexHudCore

final class AuthDecoderTests: XCTestCase {
    func testDecodesEmailFromJWT() throws {
        let payload = "{\"email\":\"user@example.com\",\"sub\":\"auth0|abc\"}"
        let jwt = makeJWT(payloadJSON: payload)
        let tempURL = try writeAuthJSON(idToken: jwt)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let decoder = AuthDecoder()
        let identity = try decoder.loadActiveAccount(from: tempURL)
        XCTAssertEqual(identity.email, "user@example.com")
        XCTAssertEqual(identity.subject, "auth0|abc")
    }

    private func makeJWT(payloadJSON: String) -> String {
        let header = "{\"alg\":\"none\"}"
        let headerB64 = base64URL(header)
        let payloadB64 = base64URL(payloadJSON)
        return "\(headerB64).\(payloadB64)."
    }

    private func base64URL(_ string: String) -> String {
        let data = string.data(using: .utf8)!
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func writeAuthJSON(idToken: String) throws -> URL {
        let json: [String: Any] = [
            "tokens": [
                "id_token": idToken,
                "account_id": "acc_123"
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try data.write(to: url)
        return url
    }
}
