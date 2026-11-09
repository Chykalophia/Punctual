//
//  MeetingSummaryView.swift
//  MeetingBar
//

import AppKit
import SwiftUI

struct MeetingSummaryPresentation: Equatable {
    let sectionTitle: String
    let eventTitle: String
    let metadata: [String]
    /// The meeting service, if any. Cleared by the caller when
    /// `showMeetingServiceIcon` is off.
    var meetingService: MeetingServices?
    /// Relative time until the meeting starts (e.g. "in 25m"); `nil` for running meetings.
    var countdown: String?

    var metadataText: String {
        metadata.joined(separator: " • ")
    }

    var sectionTitleText: String {
        guard let countdown, !countdown.isEmpty else { return sectionTitle }
        return "\(sectionTitle) • \(countdown)"
    }
}

struct MeetingSummaryView: View {
    let presentation: MeetingSummaryPresentation
    var onJoin: (() -> Void)?

    /// Whether the Join control reads as a call to action (see `EventActionProminence`).
    var isActionImminent: Bool = true

    /// The card's horizontal inset. Pass `0` when the container (e.g. `PanelCard`)
    /// already supplies one.
    var horizontalPadding: CGFloat = 12

    @State private var isHovered = false

    /// The meeting service icon; `nil` when there is no online meeting, so the
    /// title sits flush with no reserved gutter.
    private var providerIcon: NSImage? {
        presentation.meetingService.map { getIconForMeetingService($0) }
    }

    /// Shared content width for the dropdown's cards and header; equals the panel width.
    static let preferredWidth: CGFloat = DropdownMetrics.standard.panelWidth
    static let preferredHeight: CGFloat = 66

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if !presentation.sectionTitleText.isEmpty {
                    Text(presentation.sectionTitleText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 7) {
                    if let providerIcon {
                        Image(nsImage: providerIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                    }

                    Text(presentation.eventTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Text(presentation.metadataText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            // Without this the Spacer below takes about half the width and truncates the title.
            .layoutPriority(1)

            if onJoin != nil {
                Spacer(minLength: 8)
                Text("notifications_meetingbar_join_event_action".loco())
                    .font(.system(size: 12, weight: isActionImminent ? .semibold : .regular))
                    .foregroundStyle(
                        isActionImminent ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary)
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .joinControlSurface(isActionImminent: isActionImminent)
                    // The pill keeps its intrinsic size; the title truncates instead.
                    .fixedSize()
                    .opacity(isHovered ? 1.0 : 0.9)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 6)
        .frame(
            maxWidth: .infinity,
            minHeight: Self.preferredHeight,
            alignment: .leading
        )
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered && onJoin != nil ? Color.primary.opacity(0.15) : Color.clear)
        )
        .contentShape(Rectangle())
        // Scoped pointerStyle, not NSCursor push/pop, which can strand the cursor
        // when the panel closes mid-hover.
        .pointerStyle(onJoin == nil ? nil : .link)
        .onHover { hovering in isHovered = hovering }
        .onTapGesture { onJoin?() }
    }
}

#Preview {
    MeetingSummaryView(
        presentation: MeetingSummaryPresentation(
            sectionTitle: "Next meeting",
            eventTitle: "Weekly product sync",
            metadata: ["10:00 – 10:30", "Zoom", "Work"],
            meetingService: .zoom,
            countdown: "in 25m"
        ),
        onJoin: {}
    )
}
