//
//  OAuthCompletionPage.swift
//  Punctual
//
//  The local page AppAuth redirects the browser to (via `successURL`) after Google sign-in.
//  It never sees the authorization code; AppAuth owns the whole OAuth exchange.
//

import Foundation
import Network

/// Serves the single "you're connected" page on 127.0.0.1.
///
/// Every request gets the same response regardless of method or path; it is not a general HTTP server.
@MainActor
final class OAuthCompletionPageServer {
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    /// The account to name on the page.
    private var accountEmail: String?

    /// Starts listening and returns the URL to redirect the browser to, or `nil`
    /// when the listener cannot bind. A `nil` result must not fail sign-in.
    ///
    /// Awaits `.ready` before reading the port: `NWListener.port` reads 0 until the socket is bound.
    func start() async -> URL? {
        stop()

        let listener: NWListener
        do {
            // `requiredInterfaceType` alone does not keep this off the network,
            // so the URL below names the loopback address explicitly.
            let parameters = NWParameters.tcp
            parameters.requiredInterfaceType = .loopback
            parameters.allowLocalEndpointReuse = true
            listener = try NWListener(using: parameters, on: .any)
        } catch {
            PunctualLogger.calendar.error(
                "Could not create the OAuth completion page listener: \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }

        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.accept(connection) }
        }
        self.listener = listener

        // `stateUpdateHandler` can fire more than once; the continuation must resume exactly once.
        let resumeOnce = OneShotGuard()
        let port: UInt16? = await withCheckedContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard resumeOnce.claim() else { return }
                    continuation.resume(returning: listener.port?.rawValue)
                case .failed, .cancelled:
                    guard resumeOnce.claim() else { return }
                    continuation.resume(returning: nil)
                default:
                    break
                }
            }
            listener.start(queue: .main)
        }

        guard let port, port != 0 else {
            stop()
            return nil
        }
        return URL(string: "http://127.0.0.1:\(port)/connected")
    }

    /// Sets the account named on the page; call before the browser is redirected.
    func setAccountEmail(_ email: String?) {
        accountEmail = email
    }

    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: .main)
        // Read and discard the request so the browser finishes sending before the reply.
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] _, _, _, _ in
            Task { @MainActor in self?.respond(on: connection) }
        }
    }

    private func respond(on connection: NWConnection) {
        let body = Data(OAuthCompletionPage.html(accountEmail: accountEmail).utf8)
        let headers = [
            "HTTP/1.1 200 OK",
            "Content-Type: text/html; charset=utf-8",
            "Content-Length: \(body.count)",
            // The page names an account, so keep it out of any cache.
            "Cache-Control: no-store",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        connection.send(
            content: Data(headers.utf8) + body,
            completion: .contentProcessed { _ in
                connection.cancel()
            }
        )
    }
}

/// Lets exactly one caller through, so a continuation resumed from a callback
/// that can fire repeatedly is resumed once.
private final class OneShotGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else { return false }
        claimed = true
        return true
    }
}

/// Builds the completion page HTML.
enum OAuthCompletionPage {
    /// Returns the self-contained page, following the system light or dark appearance.
    ///
    /// All styles and images are inline: every request gets this page and the
    /// connection closes after one response, so the browser can't fetch anything else.
    static func html(accountEmail: String?) -> String {
        let account = accountEmail.flatMap { $0.isEmpty ? nil : $0 }
        let accountLine = account.map {
            "<p class=\"account\">\(escape($0))</p>"
        } ?? ""

        return """
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape("oauth_page_title".loco()))</title>
        <style>
          :root {
            color-scheme: light dark;
            --bg: #f5f5f7;
            --card: #ffffff;
            --text: #1d1d1f;
            --muted: #6e6e73;
            --accent: #34c759;
            --border: rgba(0, 0, 0, 0.08);
          }
          @media (prefers-color-scheme: dark) {
            :root {
              --bg: #1c1c1e;
              --card: #2c2c2e;
              --text: #f5f5f7;
              --muted: #a1a1a6;
              --border: rgba(255, 255, 255, 0.1);
            }
          }
          * { box-sizing: border-box; }
          body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
            background: var(--bg);
            color: var(--text);
            font: 16px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
          }
          .card {
            width: 100%;
            max-width: 420px;
            background: var(--card);
            border: 1px solid var(--border);
            border-radius: 14px;
            padding: 32px;
            text-align: center;
          }
          .check {
            width: 48px;
            height: 48px;
            margin: 0 auto 20px;
            border-radius: 50%;
            background: var(--accent);
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .check svg { width: 26px; height: 26px; }
          h1 { margin: 0 0 8px; font-size: 20px; font-weight: 600; letter-spacing: -0.01em; }
          .account {
            margin: 0 0 20px;
            font-size: 14px;
            color: var(--muted);
            word-break: break-all;
          }
          p.next { margin: 0; font-size: 14px; color: var(--muted); }
          .app { margin-top: 24px; font-size: 12px; color: var(--muted); }
        </style>
        </head>
        <body>
          <main class="card">
            <div class="check" aria-hidden="true">
              <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="3"
                   stroke-linecap="round" stroke-linejoin="round">
                <path d="M4 12.5l5.5 5.5L20 7"/>
              </svg>
            </div>
            <h1>\(escape("oauth_page_heading".loco()))</h1>
            \(accountLine)
            <p class="next">\(escape("oauth_page_next_steps".loco()))</p>
            <p class="app">Punctual</p>
          </main>
        </body>
        </html>
        """
    }

    /// HTML-escapes untrusted text, such as the account address from Google's ID token.
    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
