//
//  MeetingProvider.swift
//  MeetingBar
//
//  Meeting-provider metadata: the struct, the catalogue of built-in providers, and
//  ID-based lookup. Pure domain data with no AppKit or Defaults imports.
//

enum MeetingOpeningMode: String, CaseIterable, Codable, Sendable {
    case meetInOne
    case googleMeetPWA
    case zoomApp
    case zoomWebApp
    case teamsApp
    case workplaceApp
    case jitsiApp
    case slackApp
    case riversideApp

    var titleKey: String {
        switch self {
        case .meetInOne:
            "preferences_meeting_opening_mode_meetinone"
        case .googleMeetPWA:
            "preferences_meeting_opening_mode_google_meet_pwa"
        case .zoomApp:
            "preferences_meeting_opening_mode_zoom_app"
        case .zoomWebApp:
            "preferences_meeting_opening_mode_zoom_web_app"
        case .teamsApp:
            "preferences_meeting_opening_mode_teams_app"
        case .workplaceApp:
            "preferences_meeting_opening_mode_workplace_app"
        case .jitsiApp:
            "preferences_meeting_opening_mode_jitsi_app"
        case .slackApp:
            "preferences_meeting_opening_mode_slack_app"
        case .riversideApp:
            "preferences_meeting_opening_mode_riverside_app"
        }
    }

    var helpKey: String? {
        switch self {
        case .googleMeetPWA:
            "preferences_meeting_opening_mode_google_meet_pwa_help"
        case .zoomWebApp:
            "preferences_meeting_opening_mode_zoom_web_app_help"
        case .workplaceApp:
            "preferences_meeting_opening_mode_workplace_app_help"
        case .meetInOne, .zoomApp, .teamsApp, .jitsiApp, .slackApp, .riversideApp:
            nil
        }
    }

    var legacyBrowserName: String? {
        switch self {
        case .meetInOne:
            "MeetInOne"
        case .zoomApp:
            "Zoom"
        case .teamsApp:
            "Teams"
        case .jitsiApp:
            "Jitsi"
        case .slackApp:
            "Slack"
        case .riversideApp:
            "Riverside"
        case .googleMeetPWA, .zoomWebApp, .workplaceApp:
            nil
        }
    }
}

/// Per-provider metadata used by detection, opening, icon rendering, and preferences.
/// For built-in providers `id` equals `MeetingServices.rawValue`, which persisted data relies on.
struct MeetingProvider: Equatable, Sendable {
    /// Stable string identity. For built-in providers this equals `MeetingServices.rawValue`.
    let id: String

    /// Human-readable display name.
    let displayName: String

    /// `NSImage(named:)` key for the provider icon.
    /// System template image names (e.g. "NSTouchBarOpenInBrowserTemplate") are valid here.
    let iconName: String

    /// Rendered icon width in points. Almost always 16.
    let iconWidth: Double

    /// Rendered icon height in points. Varies by provider logo aspect ratio.
    let iconHeight: Double

    /// URL detection regex pattern. `nil` for providers that don't use URL matching
    /// (e.g. phone, facetimeaudio, url catch-all, other).
    let regexPattern: String?

    /// Explicit app/web/PWA choices available in addition to real browsers.
    let openingModes: [MeetingOpeningMode]

    /// Legacy native-app `Browser` sentinel name, for migrations and older call sites.
    var nativeAppBrowserName: String? {
        openingModes.compactMap(\.legacyBrowserName).first
    }
}

// MARK: - Lookup

extension MeetingProvider {
    /// Look up a provider by its stable string `id`.
    static func provider(for id: String) -> MeetingProvider? {
        byID[id]
    }

    /// Convenience lookup directly from a `MeetingServices` case.
    static func provider(for service: MeetingServices) -> MeetingProvider? {
        provider(for: service.rawValue)
    }

    /// Regex patterns of the built-in providers, keyed by `MeetingServices`.
    static var regexPatterns: [MeetingServices: String] {
        var result: [MeetingServices: String] = [:]
        for provider in all {
            guard let pattern = provider.regexPattern,
                let service = MeetingServices(rawValue: provider.id)
            else { continue }
            result[service] = pattern
        }
        return result
    }

    private static let byID: [String: MeetingProvider] = {
        Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }()
}

// MARK: - Built-in providers

extension MeetingProvider {
    // swiftlint:disable function_body_length
    static let all: [MeetingProvider] = {
        // Most icons are 16pt square; other heights are explicit.
        func make(
            _ service: MeetingServices,
            icon: String,
            height: Double = 16,
            pattern: String? = nil,
            displayName: String? = nil,
            openingModes: [MeetingOpeningMode] = []
        ) -> MeetingProvider {
            MeetingProvider(
                id: service.rawValue,
                displayName: displayName ?? service.rawValue,
                iconName: icon,
                iconWidth: 16,
                iconHeight: height,
                regexPattern: pattern,
                openingModes: openingModes
            )
        }

        return [
            // Phone: no URL pattern, opened via tel://
            make(.phone, icon: "NSTouchBarCommunicationAudioTemplate"),

            make(
                .meet,
                icon: "google_meet_icon",
                height: 13.2,
                pattern: #"https?://meet.google.com/(_meet/)?[a-z-]+"#,
                openingModes: [.meetInOne, .googleMeetPWA]),

            make(
                .protonMeet,
                icon: "no_online_session",
                pattern: #"https?://meet\.proton\.me/join/[A-Za-z0-9-]+(?:[?#][^\s]*)?"#),

            make(
                .meetStream,
                icon: "google_meet_icon",
                height: 13.2,
                pattern: #"https?://stream\.meet\.google\.com/stream/[a-z0-9-]+"#),

            // Google Hangouts (deprecated)
            make(
                .hangouts,
                icon: "google_hangouts_icon",
                pattern: #"https?://hangouts\.google\.com/[^\s]*"#),

            make(
                .duo,
                icon: "google_duo_icon",
                pattern: #"https?://duo\.app\.goo\.gl/[^\s]*"#),

            // Zoom (web)
            make(
                .zoom,
                icon: "zoom_icon",
                pattern:
                    #"https:\/\/(?:[a-zA-Z0-9-.]+)?zoom(-x)?\.(?:us|com|com\.cn|de)\/(?:my|[a-z]{1,2}|webinar)\/[-a-zA-Z0-9()@:%_\+.~#?&=\/]*"#,
                openingModes: [.zoomApp, .zoomWebApp]
            ),

            // Zoom (native app scheme)
            make(
                .zoom_native,
                icon: "zoom_icon",
                pattern:
                    #"zoommtg://([a-z0-9-.]+)?zoom(-x)?\.(?:us|com|com\.cn|de)/join[-a-zA-Z0-9()@:%_\+.~#?&=\/]*"#
            ),

            make(
                .zoomgov,
                icon: "zoom_icon",
                pattern: #"https?://([a-z0-9.]+)?zoomgov\.com/j/[a-zA-Z0-9?&=]+"#),

            // Reclaim.ai (uses Zoom links)
            make(
                .reclaim,
                icon: "zoom_icon",
                pattern: #"https?://reclaim\.ai/z/[A-Za-z0-9./]+"#),

            make(
                .teams,
                icon: "ms_teams_icon",
                pattern:
                    #"https?://(gov\.)?teams\.microsoft\.(com|us)/(l/meetup-join/[a-zA-Z0-9_%\/=\-\+\.?]+(?:&[^\s]+)?|meet/\d+\?p=[A-Za-z0-9_\-]+(?:&[^\s]+)?)"#,
                openingModes: [.teamsApp]
            ),

            make(
                .webex,
                icon: "webex_icon",
                pattern:
                    #"https?://(?:[A-Za-z0-9-]+\.)?webex\.com(?:(?:/[-A-Za-z0-9]+/j\.php\?MTID=[A-Za-z0-9]+(?:&\S*)?)|(?:/(?:meet|join)/[A-Za-z0-9\-._@]+(?:\?\S*)?))"#
            ),

            make(
                .jitsi,
                icon: "jitsi_icon",
                pattern: #"https?://meet\.jit\.si/[^\s]*"#,
                openingModes: [.jitsiApp]),

            make(
                .chime,
                icon: "amazon_chime_icon",
                pattern: #"https?://([a-z0-9-.]+)?chime\.aws/[0-9]*"#),

            make(
                .ringcentral,
                icon: "ringcentral_icon",
                pattern: #"https?://([a-z0-9.]+)?ringcentral\.com/[^\s]*"#),

            make(
                .gotomeeting,
                icon: "gotomeeting_icon",
                pattern: #"https?://([a-z0-9.]+)?gotomeeting\.com/[^\s]*"#),

            make(
                .gotowebinar,
                icon: "gotowebinar_icon",
                pattern: #"https?://([a-z0-9.]+)?gotowebinar\.com/[^\s]*"#),

            make(
                .bluejeans,
                icon: "bluejeans_icon",
                pattern: #"https?://([a-z0-9.]+)?bluejeans\.com/[^\s]*"#),

            make(
                .eight_x_eight,
                icon: "8x8_icon",
                height: 8,
                pattern: #"https?://8x8\.vc/[^\s]*"#),

            make(
                .demio,
                icon: "demio_icon",
                pattern: #"https?://event\.demio\.com/[^\s]*"#),

            make(
                .join_me,
                icon: "joinme_icon",
                height: 10,
                pattern: #"https?://join\.me/[^\s]*"#),

            make(
                .whereby,
                icon: "whereby_icon",
                height: 18,
                pattern: #"https?://whereby\.com/[^\s]*"#),

            make(
                .uberconference,
                icon: "uberconference_icon",
                pattern: #"https?://uberconference\.com/[^\s]*"#),

            // Blizz (rebranded to TeamViewer Meeting)
            make(
                .blizz,
                icon: "teamviewer_meeting_icon",
                pattern: #"https?://go\.blizz\.com/[^\s]*"#),

            make(
                .teamviewer_meeting,
                icon: "teamviewer_meeting_icon",
                pattern: #"https?://go\.teamviewer\.com/[^\s]*"#),

            make(
                .vsee,
                icon: "vsee_icon",
                pattern: #"https?://vsee\.com/[^\s]*"#),

            make(
                .starleaf,
                icon: "starleaf_icon",
                pattern: #"https?://meet\.starleaf\.com/[^\s]*"#),

            make(
                .voov,
                icon: "voov_icon",
                pattern: #"https?://voovmeeting\.com/[^\s]*"#),

            make(
                .facebook_workspace,
                icon: "facebook_workplace_icon",
                pattern: #"https?://([a-z0-9-.]+)?workplace\.com/groupcall/[^\s]+"#,
                displayName: "Workplace",
                openingModes: [.workplaceApp]),

            make(
                .lifesize,
                icon: "lifesize_icon",
                pattern: #"https?://call\.lifesizecloud\.com/[^\s]*"#),

            make(
                .skype,
                icon: "skype_icon",
                pattern: #"https?://join\.skype\.com/[^\s]*"#),

            make(
                .skype4biz,
                icon: "skype_business_icon",
                pattern: #"https?://meet\.lync\.com/[^\s]*"#),

            // Skype for Business (self-hosted)
            make(
                .skype4biz_selfhosted,
                icon: "skype_business_icon",
                pattern: #"https?:\/\/(meet|join)\.[^\s]*\/[a-z0-9.]+/meet\/[A-Za-z0-9./]+"#),

            // FaceTime (link-based)
            make(
                .facetime,
                icon: "facetime_icon",
                pattern: #"https://facetime\.apple\.com/join[^\s]*"#),

            // FaceTime Audio: no URL pattern, opened via facetime-audio://
            make(.facetimeaudio, icon: "facetime_icon"),

            make(
                .youtube,
                icon: "youtube_icon",
                pattern: #"https?://((www|m)\.)?(youtube\.com|youtu\.be)/[^\s]*"#),

            make(
                .vonageMeetings,
                icon: "vonage_icon",
                pattern: #"https?://meetings\.vonage\.com/[0-9]{9}"#),

            make(
                .around,
                icon: "no_online_session",
                pattern: #"https?://(meet\.)?around\.co/[^\s]*"#),

            make(
                .jam,
                icon: "no_online_session",
                pattern: #"https?://jam\.systems/[^\s]*"#),

            make(
                .discord,
                icon: "discord_icon",
                height: 12.13,
                pattern:
                    #"(http|https|discord)://(www\.)?(canary\.)?discord(app)?\.([a-zA-Z]{2,})(.+)?"#
            ),

            make(
                .blackboard_collab,
                icon: "no_online_session",
                pattern: #"https?://us\.bbcollab\.com/[^\s]*"#),

            // Any Link: catch-all, no URL pattern
            make(.url, icon: "NSTouchBarOpenInBrowserTemplate"),

            make(
                .coscreen,
                icon: "coscreen_icon",
                pattern: #"https?://join\.coscreen\.co/[^\s]*"#),

            make(
                .vowel,
                icon: "vowel_icon",
                pattern: #"https?://([a-z0-9.]+)?vowel\.com/#/g/[^\s]*"#),

            make(
                .zhumu,
                icon: "zhumu_icon",
                pattern: #"https://welink\.zhumu\.com/(?:j/[0-9]+(?:\?pwd=[A-Za-z0-9]+)?|wc/join/[0-9]+\?wpk=[A-Za-z0-9]+)"#),

            make(
                .lark,
                icon: "lark_icon",
                pattern: #"https://vc\.larksuite\.com/j/[0-9]+"#),

            make(
                .feishu,
                icon: "feishu_icon",
                pattern: #"https://vc\.feishu\.cn/j/[0-9]+"#),

            make(
                .vimeo,
                icon: "vimeo_icon",
                pattern:
                    #"https://vimeo\.com/(showcase|event)/[0-9]+|https://venues\.vimeo\.com/[^\s]+"#
            ),

            make(
                .ovice,
                icon: "ovice_icon",
                pattern: #"https://([a-z0-9-.]+)?ovice\.(in|com)/[^\s]*"#),

            make(
                .luma,
                icon: "no_online_session",
                pattern: #"https://lu\.ma/join/[^\s]*"#),

            make(
                .preply,
                icon: "preply_icon",
                pattern: #"https://preply\.com/[^\s]*"#),

            make(
                .userzoom,
                icon: "userzoom_icon",
                pattern: #"https://go\.userzoom\.com/participate/[a-z0-9-]+"#),

            make(
                .venue,
                icon: "venue_icon",
                height: 4,
                pattern: #"https://app\.venue\.live/app/[^\s]*"#),

            make(
                .teemyco,
                icon: "teemyco_icon",
                pattern: #"https://app\.teemyco\.com/room/[^\s]*"#),

            make(
                .demodesk,
                icon: "demodesk_icon",
                pattern: #"https://demodesk\.com/[^\s]*"#),

            make(
                .zoho_cliq,
                icon: "zoho_cliq_icon",
                pattern: #"https://cliq\.zoho\.eu/meetings/[^\s]*"#),

            // Slack (huddle)
            make(
                .slack,
                icon: "slack_icon",
                pattern: #"https?://app\.slack\.com/huddle/[A-Za-z0-9./]+"#,
                openingModes: [.slackApp]),

            make(
                .gather,
                icon: "gather_icon",
                pattern:
                    #"https?://app.gather.town/app/[A-Za-z0-9]+/[A-Za-z0-9_%\-]+\?(spawnToken|meeting)=[^\s]*"#
            ),

            make(
                .pop,
                icon: "pop_icon",
                pattern: #"https?://pop\.com/j/[0-9-]+"#),

            make(
                .chorus,
                icon: "chorus_icon",
                pattern: #"https?://go\.chorus\.ai/[^\s]+"#),

            make(
                .gong,
                icon: "gong_icon",
                pattern: #"https?://([a-z0-9-.]+)?join\.gong\.io/[^\s]+"#),

            make(
                .livestorm,
                icon: "livestorm_icon",
                pattern: #"https?://app\.livestorm\.com/p/[^\s]+"#),

            make(
                .tuple,
                icon: "tuple_icon",
                pattern: #"https://tuple\.app/c/[^\s]*"#),

            make(
                .pumble,
                icon: "pumble_icon",
                pattern: #"https?://meet\.pumble\.com/[a-z-]+"#),

            make(
                .suitConference,
                icon: "suit_conference_icon",
                pattern: #"https?://([a-z0-9.]+)?conference\.istesuit\.com/[^\s]*+"#),

            make(
                .doxyMe,
                icon: "doxy_me_icon",
                pattern: #"https://([a-z0-9.]+)?doxy\.me/[^\s]*"#),

            make(
                .calcom,
                icon: "calcom_icon",
                pattern: #"https?://app.cal\.com/video/[A-Za-z0-9./]+"#),

            make(
                .zmPage,
                icon: "zm_page_icon",
                pattern: #"https?://([a-zA-Z0-9.]+)\.zm\.page"#),

            make(
                .livekit,
                icon: "livekit_icon",
                pattern: #"https?://meet[a-zA-Z0-9.]*\.livekit\.io/rooms/[a-zA-Z0-9-#]+"#),

            make(
                .meetecho,
                icon: "meetecho_icon",
                pattern: #"https?://meetings\.conf\.meetecho\.com/.+"#),

            make(
                .streamyard,
                icon: "streamyard_icon",
                pattern:
                    #"https://(?:www\.)?streamyard\.com/(?:guest/)?([a-z0-9]{8,13})(?:/|\?[^ \n]*)?"#
            ),

            make(
                .riverside,
                icon: "riverside_icon",
                pattern: #"https?://riverside\.(com|fm)/studio/[^\s]*"#,
                openingModes: [.riversideApp]),

            // Other: catch-all for custom regex matches, no URL pattern
            make(.other, icon: "no_online_session")
        ]
    }()
    // swiftlint:enable function_body_length
}
