//
//  OAuthCompletionPageTests.swift
//  PunctualTests
//
//  Tests for the page shown in the browser after the Google OAuth redirect.
//

import XCTest

@testable import Punctual

@MainActor
final class OAuthCompletionPageTests: XCTestCase {
    // MARK: - Content

    func test_pageNamesTheConnectedAccount() {
        let html = OAuthCompletionPage.html(accountEmail: "peter@example.com")
        XCTAssertTrue(html.contains("peter@example.com"))
    }

    func test_pageOmitsTheAccountLineWhenThereIsNoEmail() {
        for empty in [nil, ""] as [String?] {
            let html = OAuthCompletionPage.html(accountEmail: empty)
            XCTAssertFalse(html.contains("class=\"account\""))
        }
    }

    func test_pageTellsTheUserWhatToDoNext() {
        let html = OAuthCompletionPage.html(accountEmail: nil)
        XCTAssertTrue(html.lowercased().contains("close this tab"))
    }

    func test_pageIsSelfContained() {
        // The socket closes after this response, so the page cannot load other resources.
        let html = OAuthCompletionPage.html(accountEmail: "a@b.com")
        XCTAssertFalse(html.contains("<link"))
        XCTAssertFalse(html.contains("src=\"http"))
        XCTAssertTrue(html.contains("<style>"))
    }

    func test_pageAdaptsToTheSystemTheme() {
        let html = OAuthCompletionPage.html(accountEmail: nil)
        XCTAssertTrue(html.contains("prefers-color-scheme: dark"))
    }

    // MARK: - Escaping

    func test_accountEmailIsHTMLEscaped() {
        let html = OAuthCompletionPage.html(accountEmail: "<script>alert(1)</script>@x.com")
        XCTAssertFalse(html.contains("<script>alert(1)</script>"))
        XCTAssertTrue(html.contains("&lt;script&gt;"))
    }

    func test_escapeCoversTheAttributeBreakingCharacters() {
        XCTAssertEqual(
            OAuthCompletionPage.escape("&<>\"'"),
            "&amp;&lt;&gt;&quot;&#39;"
        )
    }

    func test_ampersandIsNotDoubleEscaped() {
        XCTAssertEqual(OAuthCompletionPage.escape("a&lt;b"), "a&amp;lt;b")
    }

    // MARK: - Serving

    func test_serverBindsLoopbackAndServesThePage() async throws {
        let server = OAuthCompletionPageServer()
        defer { server.stop() }

        server.setAccountEmail("peter@example.com")
        guard let url = await server.start() else {
            return XCTFail("completion page listener did not bind")
        }

        XCTAssertEqual(url.host, "127.0.0.1", "must never bind a routable address")
        XCTAssertNotNil(url.port)

        let (data, response) = try await URLSession.shared.data(from: url)
        let http = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(http.statusCode, 200)
        XCTAssertEqual(
            http.value(forHTTPHeaderField: "Content-Type"),
            "text/html; charset=utf-8"
        )
        XCTAssertEqual(http.value(forHTTPHeaderField: "Cache-Control"), "no-store")

        let body = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(body.contains("peter@example.com"))
        XCTAssertTrue(body.contains("<!doctype html>"))
    }

    func test_anyPathServesThePage() async throws {
        let server = OAuthCompletionPageServer()
        defer { server.stop() }
        guard let url = await server.start() else {
            return XCTFail("completion page listener did not bind")
        }

        let other = try XCTUnwrap(URL(string: "http://127.0.0.1:\(url.port!)/anything"))
        let (data, response) = try await URLSession.shared.data(from: other)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        XCTAssertTrue(try XCTUnwrap(String(data: data, encoding: .utf8)).contains("<!doctype html>"))
    }

    func test_stoppingReleasesThePort() async throws {
        let server = OAuthCompletionPageServer()
        guard let url = await server.start() else {
            return XCTFail("completion page listener did not bind")
        }
        let port = try XCTUnwrap(url.port)
        server.stop()

        // Restarting must bind a fresh port rather than fail on the old one.
        let restarted = await server.start()
        defer { server.stop() }
        XCTAssertNotNil(restarted)
        XCTAssertNotEqual(restarted?.port, port)
    }
}
