import Foundation

public struct AuthAccountIdentity: Equatable {
    public let email: String
    public let subject: String?
    public let accountId: String?
}

public enum AuthDecoderError: Error, Equatable {
    case fileNotFound
    case invalidJSON
    case missingToken
    case invalidJWT
    case missingEmail
}

public struct AuthDecoder {
    public init() {}

    public func loadActiveAccount(from authJSONURL: URL) throws -> AuthAccountIdentity {
        guard FileManager.default.fileExists(atPath: authJSONURL.path) else {
            throw AuthDecoderError.fileNotFound
        }
        let data = try Data(contentsOf: authJSONURL)
        let json = try JSONSerialization.jsonObject(with: data)
        guard let dict = json as? [String: Any] else {
            throw AuthDecoderError.invalidJSON
        }
        guard let tokens = dict["tokens"] as? [String: Any] else {
            throw AuthDecoderError.missingToken
        }
        guard let idToken = tokens["id_token"] as? String else {
            throw AuthDecoderError.missingToken
        }
        let payload = try decodeJWTPayload(idToken)
        guard let email = payload["email"] as? String else {
            throw AuthDecoderError.missingEmail
        }
        let subject = payload["sub"] as? String
        let accountId = tokens["account_id"] as? String
        return AuthAccountIdentity(email: email, subject: subject, accountId: accountId)
    }

    private func decodeJWTPayload(_ jwt: String) throws -> [String: Any] {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { throw AuthDecoderError.invalidJWT }
        let payloadPart = String(parts[1])
        guard let data = Data(base64URLEncoded: payloadPart) else {
            throw AuthDecoderError.invalidJWT
        }
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let dict = obj as? [String: Any] else {
            throw AuthDecoderError.invalidJWT
        }
        return dict
    }
}

private extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = 4 - base64.count % 4
        if padding < 4 {
            base64.append(String(repeating: "=", count: padding))
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        self = data
    }
}
