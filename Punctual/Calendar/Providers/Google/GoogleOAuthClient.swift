//
//  GoogleOAuthClient.swift
//  Punctual
//
//  Pure resolution of the Google OAuth client the app signs in with: the one
//  shipped in the build or a user-supplied one, plus client ID and secret normalization.
//

import Foundation

/// A resolved Google OAuth client: what the app will actually authenticate as.
public struct GoogleOAuthClient: Equatable, Sendable {
    /// Where this client came from.
    public enum Origin: String, Equatable, Sendable {
        /// Compiled into this build from `XCConfig/GoogleSecrets.xcconfig`.
        case shipped
        /// Entered by the user in Preferences.
        case userSupplied
    }

    /// The full client ID, always in `<number>.apps.googleusercontent.com` form
    /// regardless of which form it was entered in.
    public let clientID: String
    /// `nil` when the client has no secret.
    ///
    /// Never `""`: AppAuth treats an empty NSString as present and switches to HTTP Basic
    /// client auth, which Google rejects with `invalid_client`.
    public let clientSecret: String?
    public let origin: Origin

    public init(clientID: String, clientSecret: String?, origin: Origin) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.origin = origin
    }

    /// Identity of the client the stored OAuth tokens were issued to, persisted so a
    /// client change discards the old tokens.
    ///
    /// Excludes the secret on purpose, so correcting a secret keeps a working session.
    public var tokenIdentity: String { clientID }
}

public enum GoogleOAuthClientResolver {
    /// The client to sign in with, or `nil` when there is no usable one.
    ///
    /// When `preferUserSupplied` is set, an invalid user-supplied client yields `nil`;
    /// it deliberately does not fall back to the shipped client.
    public static func resolve(
        shipped: GoogleOAuthClient?,
        userSupplied: GoogleOAuthClient?,
        preferUserSupplied: Bool
    ) -> GoogleOAuthClient? {
        if preferUserSupplied {
            return userSupplied
        }
        return shipped
    }

    /// Builds a client from raw entered/configured strings, or `nil` when the ID
    /// is unusable.
    public static func make(
        clientID rawClientID: String,
        clientSecret rawSecret: String,
        origin: GoogleOAuthClient.Origin
    ) -> GoogleOAuthClient? {
        guard let clientID = normalizedClientID(rawClientID) else { return nil }
        return GoogleOAuthClient(
            clientID: clientID,
            clientSecret: normalizedSecret(rawSecret),
            origin: origin
        )
    }

    /// Normalizes a client ID entered as either the full
    /// `<number>.apps.googleusercontent.com` form or just the number.
    /// - Returns: The full client ID, or `nil` for empty input, the build placeholder,
    ///   or a value containing a scheme or path.
    public static func normalizedClientID(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(placeholderPrefix) else { return nil }

        let number = trimmed.hasSuffix(clientIDSuffix)
            ? String(trimmed.dropLast(clientIDSuffix.count))
            : trimmed
        guard !number.isEmpty, number != "." else { return nil }
        guard !number.contains("/"), !number.contains(":") else { return nil }

        return number + clientIDSuffix
    }

    /// Trims a secret, returning `nil` for empty input or the build placeholder.
    public static func normalizedSecret(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(placeholderPrefix) else { return nil }
        return trimmed
    }

    /// Whether a raw string would produce a usable client ID.
    public static func isValidClientID(_ raw: String) -> Bool {
        normalizedClientID(raw) != nil
    }

    private static let clientIDSuffix = ".apps.googleusercontent.com"
    private static let placeholderPrefix = "REPLACE_BY_YOUR"
}
