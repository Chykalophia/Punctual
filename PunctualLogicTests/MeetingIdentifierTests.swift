//
//  MeetingIdentifierTests.swift
//  PunctualLogicTests
//
//  Tests for meeting-ID extraction from join URLs.
//

import XCTest

@testable import PunctualLogic

final class MeetingIdentifierTests: XCTestCase {
    private func identifier(_ string: String) -> MeetingIdentifier? {
        guard let url = URL(string: string) else {
            XCTFail("test URL did not parse: \(string)")
            return nil
        }
        return MeetingIdentifierPolicy.identifier(from: url)
    }

    // MARK: - Zoom

    func testZoomJoinURLYieldsNumericID() {
        let result = identifier("https://us02web.zoom.us/j/12345678901")
        XCTAssertEqual(result?.value, "12345678901")
        XCTAssertEqual(result?.kind, .meetingID)
    }

    func testZoomIDSurvivesAQueryPassword() {
        // The password belongs to the link, not the id.
        XCTAssertEqual(identifier("https://us02web.zoom.us/j/98765432?pwd=aBcDeF")?.value, "98765432")
    }

    func testZoomTenantPrefixDoesNotHideTheID() {
        // `/company/j/<id>` is common on business accounts; a positional parse
        // would read "j" as the id here.
        XCTAssertEqual(identifier("https://zoom.us/chykalophia/j/5551234567")?.value, "5551234567")
    }

    func testZoomWebinarAndPersonalLinkForms() {
        XCTAssertEqual(identifier("https://zoom.us/w/1112223333")?.value, "1112223333")
        XCTAssertEqual(identifier("https://zoom.us/s/4445556666")?.value, "4445556666")
    }

    func testZoomPersonalRoomIsARoomNotAnID() {
        let result = identifier("https://zoom.us/my/peter.krzyzek")
        XCTAssertEqual(result?.value, "peter.krzyzek")
        XCTAssertEqual(result?.kind, .room, "a named personal room is not a dial-in id")
    }

    func testZoomGovAndZhumuShareTheGrammar() {
        XCTAssertEqual(identifier("https://www.zoomgov.com/j/1602222333")?.value, "1602222333")
        XCTAssertEqual(identifier("https://welink.zhumu.com/j/7778889990")?.value, "7778889990")
    }

    func testZoomWithoutADigitRunYieldsNothing() {
        XCTAssertNil(identifier("https://zoom.us/download"))
        XCTAssertNil(identifier("https://zoom.us/j/not-a-number"))
    }

    // MARK: - Google Meet

    func testGoogleMeetCodeKeepsItsHyphens() {
        // The hyphenated form is canonical for Meet, so it is kept.
        let result = identifier("https://meet.google.com/abc-defg-hij")
        XCTAssertEqual(result?.value, "abc-defg-hij")
        XCTAssertEqual(result?.kind, .meetingID)
    }

    func testGoogleMeetNonCodePathsYieldNothing() {
        XCTAssertNil(identifier("https://meet.google.com/new"))
        XCTAssertNil(identifier("https://meet.google.com/landing"))
        // Right shape, wrong group lengths.
        XCTAssertNil(identifier("https://meet.google.com/ab-cdef-ghi"))
        // Digits are not part of a Meet code.
        XCTAssertNil(identifier("https://meet.google.com/abc-1234-hij"))
    }

    // MARK: - Teams: the deliberate nil

    func testTeamsYieldsNothingRatherThanAThreadID() {
        // The thread id in a Teams URL is not the dial-in conference ID.
        XCTAssertNil(identifier(
            "https://teams.microsoft.com/l/meetup-join/19%3ameeting_ZGJhY2Q%40thread.v2/0"
        ))
    }

    // MARK: - Webex

    func testWebexPersonalRoomIsExtractable() {
        let result = identifier("https://chykalophia.webex.com/meet/peter")
        XCTAssertEqual(result?.value, "peter")
        XCTAssertEqual(result?.kind, .room)
    }

    func testWebexScheduledMeetingTokenIsNotAnID() {
        // MTID is an opaque token, not the meeting number.
        XCTAssertNil(identifier("https://chykalophia.webex.com/webappng/sites/x/j.php?MTID=m1234"))
    }

    // MARK: - Other numeric services

    func testChimeGoToAndBlueJeans() {
        XCTAssertEqual(identifier("https://chime.aws/1234567890")?.value, "1234567890")
        XCTAssertEqual(identifier("https://www.gotomeeting.com/join/123456789")?.value, "123456789")
        XCTAssertEqual(identifier("https://bluejeans.com/123456789")?.value, "123456789")
    }

    // MARK: - Named rooms

    func testNamedRoomServices() {
        XCTAssertEqual(identifier("https://meet.jit.si/chykalophia-standup")?.kind, .room)
        XCTAssertEqual(identifier("https://whereby.com/chykalophia")?.value, "chykalophia")
        XCTAssertEqual(identifier("https://8x8.vc/daily")?.value, "daily")
    }

    func testRoomHostMarketingPagesAreNotRooms() {
        // Otherwise a link to the pricing page offers to copy "pricing".
        XCTAssertNil(identifier("https://whereby.com/pricing"))
        XCTAssertNil(identifier("https://whereby.com/about"))
    }

    func testDeepPathOnARoomHostIsNotARoom() {
        // A settings or recording page, not something anyone can join.
        XCTAssertNil(identifier("https://whereby.com/chykalophia/settings"))
    }

    // MARK: - Nothing to extract

    func testUnknownHostsAndBarePathsYieldNothing() {
        XCTAssertNil(identifier("https://example.com/some/meeting"))
        XCTAssertNil(identifier("https://zoom.us"))
        XCTAssertNil(identifier("https://meet.google.com"))
    }

    func testLinkConvenienceMatchesTheURLForm() {
        let url = URL(string: "https://us02web.zoom.us/j/12345678901")!
        let viaLink = MeetingIdentifierPolicy.identifier(from: MeetingLink(service: .zoom, url: url))
        XCTAssertEqual(viaLink, MeetingIdentifierPolicy.identifier(from: url))
    }
}
