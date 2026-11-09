//
//  GoogleLoopbackRedirectTests.swift
//  PunctualTests
//
//  Tests for the loopback HTTP listener that receives the Google OAuth redirect: it binds,
//  returns a usable `http://127.0.0.1:<port>/` redirect URI, and tears down cleanly.
//

import AppAuth
import XCTest

@testable import Punctual

@MainActor
final class GoogleLoopbackRedirectTests: XCTestCase {
    private var handlers: [OIDRedirectHTTPHandler] = []

    override func tearDown() {
        handlers.forEach { $0.cancelHTTPListener() }
        handlers.removeAll()
        super.tearDown()
    }

    private func startListener() throws -> URL {
        let handler = OIDRedirectHTTPHandler(successURL: nil)
        handlers.append(handler)
        var error: NSError?
        let url = handler.startHTTPListener(&error)
        if let error { throw error }
        return url
    }

    func test_listenerBindsAndReturnsALoopbackRedirectURI() throws {
        let url = try startListener()

        XCTAssertEqual(url.scheme, "http", "loopback redirects are plain http by design")
        XCTAssertEqual(
            url.host, "127.0.0.1",
            "must bind the loopback interface only — never a routable address")
        guard let port = url.port else {
            return XCTFail("redirect URI carries no port; the request would be unroutable")
        }
        XCTAssertGreaterThan(port, 0)
    }

    func test_eachListenerGetsItsOwnPort() throws {
        let first = try startListener()
        let second = try startListener()
        XCTAssertNotEqual(first.port, second.port)
    }

    func test_cancellingReleasesTheListener() throws {
        let handler = OIDRedirectHTTPHandler(successURL: nil)
        var error: NSError?
        _ = handler.startHTTPListener(&error)
        XCTAssertNil(error)

        handler.cancelHTTPListener()
        // Cancelling twice must not trap; `signIn`'s `defer` can run after the listener stopped itself.
        handler.cancelHTTPListener()
    }

    /// Must be the loopback literal: `localhost` can resolve to IPv6 or be redirected by a hosts entry.
    func test_redirectURIUsesTheLoopbackLiteralNotLocalhost() throws {
        let url = try startListener()
        XCTAssertFalse(url.absoluteString.contains("localhost"))
    }
}
