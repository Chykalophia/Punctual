//
//  MeetingPrepLinks.swift
//  MeetingBar
//
//  Extracts meeting-prep links (docs, design files, repos, tickets) from an invite,
//  excluding the join link. Foundation-only, so it is unit-tested hostlessly.
//

import Foundation

/// Host-classified category of a prep link. The host layer maps each kind to an
/// SF Symbol; `MeetingPrepLinks.displayTitle` uses it to label the menu row.
enum PrepLinkKind: Equatable {
    case figma
    case notion
    case github
    case googleDoc
    case googleSheet
    case googleSlides
    case googleDrive
    case linear
    case jira
    case confluence
    case loom
    case generic
}

/// A single reference link extracted from an event's notes/location.
struct PrepLink: Equatable {
    let url: String
    let kind: PrepLinkKind
    let displayTitle: String
}

enum MeetingPrepLinks {
    /// Maximum links returned, so a link-dump description can't flood the submenu.
    static let maxLinks = 8

    /// Finds every http(s) URL across `notes` + `location`, drops the meeting
    /// JOIN link (`excludedURLs`) and any obvious real-time meeting-join host,
    /// de-duplicates case-insensitively on the full URL, classifies each survivor
    /// by host, and returns up to `maxLinks` in first-seen order.
    static func extract(
        notes: String?,
        location: String?,
        excluding excludedURLs: [String]
    ) -> [PrepLink] {
        let sources = [notes, location].compactMap { $0 }
        guard !sources.isEmpty else { return [] }
        let text = sources.joined(separator: "\n")

        let excluded = Set(excludedURLs.map(normalizedForComparison))

        var seen = Set<String>()
        var result: [PrepLink] = []

        for raw in urlStrings(in: text) {
            let cleaned = trimTrailingPunctuation(raw)
            guard let components = URLComponents(string: cleaned),
                  let rawHost = components.host?.lowercased(),
                  !rawHost.isEmpty
            else { continue }

            let normalized = normalizedForComparison(cleaned)
            if excluded.contains(normalized) { continue }
            if isMeetingJoinHost(rawHost) { continue }
            guard seen.insert(normalized).inserted else { continue }

            let host = canonicalHost(rawHost)
            let kind = classify(host: host, path: components.path)
            let title = displayTitle(kind: kind, host: host, path: components.path)
            result.append(PrepLink(url: cleaned, kind: kind, displayTitle: title))

            if result.count >= maxLinks { break }
        }
        return result
    }

    // MARK: - URL scan

    // Stops at whitespace, quotes, angle brackets and closing brackets so HTML attributes
    // and wrapping punctuation don't bleed into the match.
    private static let urlRegex = try? NSRegularExpression(
        pattern: #"https?://[^\s"'<>)\]}]+"#,
        options: [.caseInsensitive]
    )

    private static func urlStrings(in text: String) -> [String] {
        guard let urlRegex else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return urlRegex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return String(text[matchRange])
        }
    }

    /// Strips sentence punctuation the regex absorbs when a URL ends a sentence.
    private static func trimTrailingPunctuation(_ raw: String) -> String {
        var trimmed = raw[...]
        let trailing: Set<Character> = [".", ",", ";", ":", "!", "?"]
        while let last = trimmed.last, trailing.contains(last) {
            trimmed = trimmed.dropLast()
        }
        return String(trimmed)
    }

    // MARK: - Normalisation

    /// Identity used for both de-dup and join-link exclusion: lower-cased and
    /// trailing-slash-insensitive so `…/Spec` and `…/Spec/` collapse together.
    private static func normalizedForComparison(_ raw: String) -> String {
        var value = trimTrailingPunctuation(raw).lowercased()
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    private static func canonicalHost(_ host: String) -> String {
        var result = host
        if result.hasSuffix(".") { result.removeLast() }
        if result.hasPrefix("www.") { result.removeFirst(4) }
        return result
    }

    private static func hostMatches(_ host: String, _ domain: String) -> Bool {
        host == domain || host.hasSuffix("." + domain)
    }

    // MARK: - Meeting-join hosts (excluded)

    /// Hosts whose links are join actions, not prep material. Host-scoped, so
    /// `meet.google.com` is excluded while `docs.google.com` is kept.
    private static let meetingJoinHosts: [String] = [
        "meet.google.com",
        "zoom.us",
        "zoomgov.com",
        "teams.microsoft.com",
        "teams.microsoft.us",
        "teams.live.com",
        "webex.com",
        "whereby.com",
        "jit.si",
        "chime.aws",
        "gotomeeting.com",
        "gotomeet.me",
        "gotowebinar.com",
        "bluejeans.com",
        "8x8.vc",
        "around.co",
        "meet.proton.me",
        "skype.com",
        "discord.gg",
        "livekit.io"
    ]

    private static func isMeetingJoinHost(_ host: String) -> Bool {
        meetingJoinHosts.contains { hostMatches(host, $0) }
    }

    // MARK: - Classification

    private static func classify(host: String, path: String) -> PrepLinkKind {
        if hostMatches(host, "figma.com") { return .figma }
        if hostMatches(host, "notion.so") || hostMatches(host, "notion.site") { return .notion }
        if hostMatches(host, "github.com") { return .github }
        if host == "docs.google.com" {
            if path.hasPrefix("/spreadsheets") { return .googleSheet }
            if path.hasPrefix("/presentation") { return .googleSlides }
            if path.hasPrefix("/document") { return .googleDoc }
            return .generic
        }
        if host == "drive.google.com" { return .googleDrive }
        if hostMatches(host, "linear.app") { return .linear }
        if hostMatches(host, "atlassian.net") {
            return path.hasPrefix("/wiki") ? .confluence : .jira
        }
        if hostMatches(host, "loom.com") { return .loom }
        return .generic
    }

    // MARK: - Display title

    /// A concise, human-readable label: the kind's brand name (plus a short
    /// `owner/repo` hint for GitHub), or the bare host for a generic link.
    /// Brand/product names are intentionally not localized.
    private static func displayTitle(kind: PrepLinkKind, host: String, path: String) -> String {
        switch kind {
        case .figma: return "Figma"
        case .notion: return "Notion"
        case .github:
            let parts = leadingPathComponents(path, max: 2)
            return parts.isEmpty ? "GitHub" : "GitHub · " + parts.joined(separator: "/")
        case .googleDoc: return "Google Doc"
        case .googleSheet: return "Google Sheet"
        case .googleSlides: return "Google Slides"
        case .googleDrive: return "Google Drive"
        case .linear: return "Linear"
        case .jira: return "Jira"
        case .confluence: return "Confluence"
        case .loom: return "Loom"
        case .generic: return host
        }
    }

    private static func leadingPathComponents(_ path: String, max: Int) -> [String] {
        Array(
            path.split(separator: "/", omittingEmptySubsequences: true)
                .prefix(max)
                .map(String.init)
        )
    }
}
