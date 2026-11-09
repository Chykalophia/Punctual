//
//  GoogleIDToken.swift
//  Punctual
//
//  Reads the signed-in account's claims out of Google's ID token.
//
//  Does not verify the signature: the token comes over TLS from this app's own PKCE
//  exchange and is used only for display. Never use these claims for a security decision.
//

import Foundation

public enum GoogleIDToken {
    /// The `email` claim, or `nil` when the token is absent, malformed, or has no email.
    public static func email(fromIDToken token: String?) -> String? {
        guard let claims = claims(fromIDToken: token) else { return nil }
        guard let email = claims["email"] as? String, !email.isEmpty else { return nil }
        return email
    }

    /// The token's payload claims, or `nil` when it is not a three-segment JWT.
    public static func claims(fromIDToken token: String?) -> [String: Any]? {
        guard let token else { return nil }
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { return nil }

        guard let payload = decodeBase64URL(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: payload) as? [String: Any]
        else { return nil }
        return json
    }

    /// Decodes unpadded base64URL, which `Data(base64Encoded:)` rejects as-is.
    public static func decodeBase64URL(_ value: String) -> Data? {
        guard !value.isEmpty else { return nil }

        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // A remainder of 1 is never valid base64, so it is rejected rather than padded.
        let remainder = normalized.count % 4
        switch remainder {
        case 0: break
        case 2: normalized += "=="
        case 3: normalized += "="
        default: return nil
        }

        return Data(base64Encoded: normalized)
    }
}
