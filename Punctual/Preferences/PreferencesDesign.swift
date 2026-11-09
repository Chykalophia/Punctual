//
//  PreferencesDesign.swift
//  MeetingBar
//
//  Copyright © 2026 Peter Krzyzek / Chykalophia. All rights reserved.
//
//  Shared Preferences building blocks: annotation help text, a persistent
//  disclosure, layout constants, a group box and a callout. Visual language
//  follows Ice 2 (teddychan/ice-2).
//

import Defaults
import SwiftUI

// MARK: - Annotation (help text under a control)

extension View {
    /// Places a localized help line in caption style directly beneath this control, in the same form row.
    ///
    /// - Parameter key: Localization key of the help text.
    func annotation(_ key: String) -> some View {
        annotation(Text(key.loco()))
    }

    func annotation(_ text: Text) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            self
            text
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A standalone help-text row for a `Section`, styled like `.annotation()`.
struct PreferencesHelpText: View {
    let key: String

    var body: some View {
        Text(key.loco())
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Disclosure (state survives window close)

/// A disclosure whose expanded state persists in `preferencesExpandedDisclosures`, keyed by `id`.
///
/// `opensAutomatically` expands it on appear; it never collapses it.
struct PreferencesDisclosure<Content: View>: View {
    let id: String
    let titleKey: String
    var subtitleKey: String?
    var opensAutomatically = false
    @ViewBuilder var content: Content

    @Default(.preferencesExpandedDisclosures) private var expandedIDs

    private var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedIDs.contains(id) },
            set: { isOpen in
                if isOpen {
                    if !expandedIDs.contains(id) { expandedIDs.append(id) }
                } else {
                    expandedIDs.removeAll { $0 == id }
                }
            }
        )
    }

    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            content
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey.loco())
                    .font(.subheadline.weight(.medium))
                if let subtitleKey {
                    Text(subtitleKey.loco())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            if opensAutomatically, !expandedIDs.contains(id) {
                expandedIDs.append(id)
            }
        }
    }
}

// MARK: - Layout constants

enum PreferencesLayout {
    static let nestedIndent: CGFloat = 16
}

extension View {
    func preferenceIndent() -> some View {
        padding(.leading, PreferencesLayout.nestedIndent)
    }
}

// MARK: - Group box (for non-form content like the About card)

/// A group box with an optional title and subtitle over content on a `.regularMaterial` fill.
///
/// For content outside a grouped form; inside a form, use `Section`.
struct PreferencesCard<Content: View>: View {
    private let title: String?
    private let subtitle: String?
    @ViewBuilder private let content: Content

    init(
        _ title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(.headline)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding([.top, .leading], 8)
                .padding(.bottom, 2)
            }
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.regularMaterial)
                )
                .containerShape(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
        }
        .focusSection()
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Callout (advisory message)

/// An SF Symbol plus a short advisory message on an `.ultraThinMaterial` background.
struct PreferenceCallout: View {
    let systemImage: String
    let message: String
    var tint: Color = .orange

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .font(.title3)
            Text(message)
                .fontWeight(.medium)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        PreferencesCard("Card title", subtitle: "A supporting subtitle line.") {
            Text("Card body content")
        }
        PreferenceCallout(
            systemImage: "exclamationmark.triangle.fill",
            message: "These settings are intended for advanced users."
        )
    }
    .padding()
    .frame(width: 420)
}
