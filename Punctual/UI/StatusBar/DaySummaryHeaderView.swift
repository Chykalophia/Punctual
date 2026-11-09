//
//  DaySummaryHeaderView.swift
//  Punctual
//
//  Greeting header at the top of the dropdown, with optional trailing icon
//  actions. Presentation-only: all strings arrive pre-localized.
//

import SwiftUI

/// A trailing icon button in the day header.
struct DaySummaryHeaderAction: Identifiable {
    let id: String
    let symbol: String
    let help: String
    let run: @MainActor () -> Void
}

struct DaySummaryHeaderView: View {
    @Environment(\.colorScheme) private var colorScheme

    let greeting: String
    let summary: String
    /// SF Symbol reflecting the time of day.
    let symbolName: String
    /// Trailing quick actions; empty renders a plain header.
    var actions: [DaySummaryHeaderAction] = []

    static let preferredWidth: CGFloat = MeetingSummaryView.preferredWidth
    /// The 26pt tile plus the vertical padding in `body`; keep in sync with both.
    static let preferredHeight: CGFloat = 48

    var body: some View {
        HStack(spacing: 10) {
            // Decorative tile: flat by design, so it reads differently from the
            // raised action buttons.
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(PanelChrome.rim(colorScheme, top: 0.12, bottom: 0.04))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(.primary)
                Text(summary)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    // Single line by design; shrink rather than wrap.
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 6)

            if !actions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(actions) { action in
                        DaySummaryHeaderButton(action: action)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(width: Self.preferredWidth, alignment: .leading)
    }
}

/// One raised header icon button with its own hover state.
private struct DaySummaryHeaderButton: View {
    let action: DaySummaryHeaderAction

    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: action.symbol)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHovered ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.13 : 0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(
                        PanelChrome.rim(
                            colorScheme,
                            top: isHovered ? 0.30 : 0.20,
                            bottom: 0.05
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: .black.opacity(isHovered ? 0.28 : 0.18), radius: 1.5, y: 1)
            .contentShape(Rectangle())
            .pointerStyle(.link)
            .onHover { hovering in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
            .onTapGesture { action.run() }
            .help(action.help)
            .accessibilityLabel(action.help)
            .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    DaySummaryHeaderView(
        greeting: "Good morning, Peter",
        summary: "3 meetings today · 4h 30m free",
        symbolName: "sunrise.fill"
    )
}
