//
//  PanelChrome.swift
//  Punctual
//
//  The panel's shared edge treatment.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import SwiftUI

enum PanelChrome {
    /// A top-to-bottom rim gradient for a raised surface (cards, buttons, chips).
    ///
    /// White in dark appearance, black at 70% of the given opacities in light.
    /// - Parameters:
    ///   - top: Opacity at the top edge.
    ///   - bottom: Opacity at the bottom edge.
    static func rim(
        _ scheme: ColorScheme,
        top: Double = 0.20,
        bottom: Double = 0.06
    ) -> LinearGradient {
        let base: Color = scheme == .dark ? .white : .black
        let scale = scheme == .dark ? 1.0 : 0.7
        return LinearGradient(
            colors: [base.opacity(top * scale), base.opacity(bottom * scale)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
