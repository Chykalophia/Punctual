//
//  GoogleOAuthClient+Punctual.swift
//  Punctual
//
//  Storage for the shipped and user-supplied Google OAuth clients, fed to
//  `GoogleOAuthClientResolver`.
//

import Defaults
import Foundation

/// The user-supplied ("bring your own") Google OAuth client.
///
/// The client ID is not secret and lives in Defaults; the optional secret is kept
/// in the Keychain so it never lands in a plist or backup.
@MainActor
enum GoogleUserOAuthClientStore {
    private static let keychainService = "Punctual.GoogleUserOAuthClientSecret"

    static var isEnabled: Bool {
        get { Defaults[.googleUseUserOAuthClient] }
        set { Defaults[.googleUseUserOAuthClient] = newValue }
    }

    static var clientID: String {
        get { Defaults[.googleUserOAuthClientID] }
        set { Defaults[.googleUserOAuthClientID] = newValue }
    }

    static var clientSecret: String {
        get {
            guard let data = Keychain.load(for: keychainService) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
        set {
            guard !newValue.isEmpty else {
                Keychain.delete(for: keychainService)
                return
            }
            Keychain.save(data: Data(newValue.utf8), for: keychainService)
        }
    }

    /// The user's client, or `nil` when what they entered cannot be used.
    static var client: GoogleOAuthClient? {
        GoogleOAuthClientResolver.make(
            clientID: clientID,
            clientSecret: clientSecret,
            origin: .userSupplied
        )
    }

    /// Deletes the entered client ID and its Keychain secret.
    static func clear() {
        Defaults[.googleUserOAuthClientID] = ""
        clientSecret = ""
    }
}

extension GoogleOAuthConfig {
    /// The client compiled into this build, or `nil` when it carries none.
    @MainActor
    static var shippedClient: GoogleOAuthClient? {
        GoogleOAuthClientResolver.make(
            clientID: clientNumber,
            clientSecret: clientSecret,
            origin: .shipped
        )
    }

    /// The client the app signs in with, or `nil` when none is usable (Google is then unavailable).
    @MainActor
    static var effectiveClient: GoogleOAuthClient? {
        GoogleOAuthClientResolver.resolve(
            shipped: shippedClient,
            userSupplied: GoogleUserOAuthClientStore.client,
            preferUserSupplied: GoogleUserOAuthClientStore.isEnabled
        )
    }
}
