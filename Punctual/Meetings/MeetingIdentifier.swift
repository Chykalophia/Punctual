//
//  MeetingIdentifier.swift
//  Punctual
//
//  Extracts a meeting's human-usable identifier (meeting number or room code) from
//  its URL. Pure URL parsing with no AppKit or Defaults.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// A meeting's identifier in the form the service's join field accepts: bare digits
/// for Zoom, hyphenated code for Google Meet.
public struct MeetingIdentifier: Equatable, Sendable {
    /// Whether this is a per-meeting ID or a named room, so the UI can label it accurately.
    public enum Kind: Equatable, Sendable {
        /// A number or code issued per meeting — dial-in-able or paste-able.
        case meetingID
        /// A named, usually persistent room (`meet.jit.si/standup`).
        case room
    }

    public let value: String
    public let kind: Kind

    public init(value: String, kind: Kind) {
        self.value = value
        self.kind = kind
    }
}

public enum MeetingIdentifierPolicy {
    /// The identifier for a meeting URL, or `nil` when the service has none a person
    /// could use. Teams returns `nil`: its URL carries a routing thread ID, not the dial-in
    /// conference ID. Matches on host and path only, so unclassified links work too.
    /// - Parameter url: the detected meeting URL.
    public static func identifier(from url: URL) -> MeetingIdentifier? {
        guard let host = url.host?.lowercased() else { return nil }

        // Case is preserved so room names keep their owner's casing.
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard !parts.isEmpty else { return nil }

        switch family(of: host) {
        case .zoom: return zoomIdentifier(parts)
        case .googleMeet: return googleMeetIdentifier(parts)
        case .webex: return webexIdentifier(parts)
        case .numericPath: return numericPathIdentifier(parts)
        case .namedRoom: return namedRoomIdentifier(parts)
        case .none: return nil
        }
    }

    // MARK: - Host families

    private enum HostFamily {
        /// Shares Zoom's grammar: `/j/<digits>` join, `/s/` personal, `/w/` webinar.
        case zoom
        case googleMeet
        case webex
        /// The id is simply the first all-digit path component.
        case numericPath
        /// The path IS the room name.
        case namedRoom
        case none
    }

    private static func family(of host: String) -> HostFamily {
        if host.contains("zoom.us") || host.contains("zoomgov.com")
            || host.contains("zhumu.com") || host.contains("zoom.com.cn")
            // RingCentral Video reuses the same /j/<digits> shape.
            || host.hasSuffix("ringcentral.com") {
            return .zoom
        }
        if host == "meet.google.com" || host.hasSuffix(".meet.google.com") {
            return .googleMeet
        }
        if host.hasSuffix("webex.com") || host.hasSuffix("webex.com.cn") {
            return .webex
        }
        if host == "chime.aws" || host.hasSuffix(".chime.aws")
            || host.hasSuffix("gotomeeting.com") || host.hasSuffix("gotowebinar.com")
            || host.hasSuffix("bluejeans.com") {
            return .numericPath
        }
        if host.hasSuffix("meet.jit.si") || host.hasSuffix("whereby.com")
            || host == "8x8.vc" || host.hasSuffix(".8x8.vc") {
            return .namedRoom
        }
        return .none
    }

    /// Convenience for a detected link.
    public static func identifier(from link: MeetingLink) -> MeetingIdentifier? {
        identifier(from: link.url)
    }

    // MARK: - Per-service rules

    /// `meet.google.com/abc-defg-hij`. Anything else on that host (`/new`,
    /// `/landing`, a lookup link) is not a code.
    private static func googleMeetIdentifier(_ parts: [String]) -> MeetingIdentifier? {
        guard let code = parts.first, isGoogleMeetCode(code) else { return nil }
        return MeetingIdentifier(value: code, kind: .meetingID)
    }

    /// Personal rooms (`/meet/<name>`) only; scheduled meetings carry an opaque
    /// `j.php?MTID=` token rather than the meeting number.
    private static func webexIdentifier(_ parts: [String]) -> MeetingIdentifier? {
        guard let index = parts.firstIndex(of: "meet"), index + 1 < parts.count else { return nil }
        return MeetingIdentifier(value: parts[index + 1], kind: .room)
    }

    /// A `/join/<digits>` prefix when present, else the first all-digit component.
    private static func numericPathIdentifier(_ parts: [String]) -> MeetingIdentifier? {
        if let index = parts.firstIndex(of: "join"), index + 1 < parts.count,
           isAllDigits(parts[index + 1]) {
            return MeetingIdentifier(value: parts[index + 1], kind: .meetingID)
        }
        guard let first = parts.first, isAllDigits(first) else { return nil }
        return MeetingIdentifier(value: first, kind: .meetingID)
    }

    /// One path component only — a deeper path is a settings or recording page,
    /// not something anyone can join.
    private static func namedRoomIdentifier(_ parts: [String]) -> MeetingIdentifier? {
        guard parts.count == 1, let room = parts.first, !isReservedRoomWord(room) else { return nil }
        return MeetingIdentifier(value: room, kind: .room)
    }

    private static func zoomIdentifier(_ parts: [String]) -> MeetingIdentifier? {
        // Scan for the join marker rather than assuming position: Zoom URLs are
        // frequently prefixed by a tenant path (`/company/j/123…`).
        for (index, part) in parts.enumerated() where ["j", "s", "w"].contains(part.lowercased()) {
            let next = index + 1
            guard next < parts.count, isAllDigits(parts[next]) else { continue }
            return MeetingIdentifier(value: parts[next], kind: .meetingID)
        }
        // `/my/<name>` is a personal-link room, not a numeric id.
        if let index = parts.firstIndex(of: "my"), index + 1 < parts.count {
            return MeetingIdentifier(value: parts[index + 1], kind: .room)
        }
        return nil
    }

    /// `abc-defg-hij` — 3 letters, 4 letters, 3 letters. Checked structurally
    /// rather than by length alone so `/new` and `/landing` do not qualify.
    private static func isGoogleMeetCode(_ candidate: String) -> Bool {
        let groups = candidate.split(separator: "-", omittingEmptySubsequences: false)
        guard groups.count == 3 else { return false }
        let expected = [3, 4, 3]
        for (group, count) in zip(groups, expected) {
            guard group.count == count else { return false }
            guard group.allSatisfy({ $0.isLetter && $0.isASCII }) else { return false }
        }
        return true
    }

    private static func isAllDigits(_ candidate: String) -> Bool {
        !candidate.isEmpty && candidate.allSatisfy(\.isNumber)
    }

    /// Paths on room hosts that are pages, not rooms. Without this, a link to
    /// `whereby.com/pricing` would offer to copy "pricing" as a room.
    private static func isReservedRoomWord(_ candidate: String) -> Bool {
        [
            "about", "blog", "contact", "download", "help", "home", "information",
            "login", "new", "pricing", "privacy", "signin", "signup", "support", "terms"
        ].contains(candidate.lowercased())
    }
}
