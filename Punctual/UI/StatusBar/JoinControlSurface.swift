//
//  JoinControlSurface.swift
//  Punctual
//
//  Shared background for the panel's Join controls: the meeting card's button
//  and the agenda rows' hover pill.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import SwiftUI

/// A drawn glass-style capsule: fill, top-lit rim, and tight shadow.
struct JoinControlSurface: ViewModifier {
    /// Whether the meeting is close enough to act on. Changes the tint only.
    let isActionImminent: Bool

    @Environment(\.colorScheme) private var colorScheme

    // Drawn on every OS version: `glassEffect` composites to a flat fill over the
    // panel's AppKit backdrop. See docs/DROPDOWN-MODERNIZATION.md §7.
    func body(content: Content) -> some View {
        drawnGlass(content)
    }

    private func drawnGlass(_ content: Content) -> some View {
        content
            .background(
                Capsule().fill(
                    isActionImminent
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(Color.primary.opacity(0.10))
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    isActionImminent
                        ? LinearGradient(
                            colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        : PanelChrome.rim(colorScheme, top: 0.24, bottom: 0.05),
                    lineWidth: 0.8
                )
            )
            .shadow(color: .black.opacity(isActionImminent ? 0.32 : 0.22), radius: 2, y: 1)
    }
}

extension View {
    /// Applies the panel's shared Join-control background.
    func joinControlSurface(isActionImminent: Bool) -> some View {
        modifier(JoinControlSurface(isActionImminent: isActionImminent))
    }
}
