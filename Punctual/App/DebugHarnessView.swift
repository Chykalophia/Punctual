//
//  DebugHarnessView.swift
//  Punctual
//
//  DEBUG-only harness window contents; see `DebugHarness.swift`. Strings are
//  deliberately not localized: developer-only labels would add dead keys to `en.lproj`.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

#if DEBUG
import Defaults
import SwiftUI

struct DebugHarnessView: View {
    let handlers: DebugHarnessHandlers

    @Default(.menuBarShowJoinAction) private var showJoinAction
    @Default(.menuBarJoinActionLeadMinutes) private var joinActionLeadMinutes
    @Default(.menuBarCountdownLeadMinutes) private var countdownLeadMinutes
    @Default(.menuBarTwoLineLayout) private var twoLineLayout
    @Default(.menuBarHighlightImminentEvent) private var highlightImminent
    @Default(.meetingProgressStyle) private var meetingProgressStyle

    @State private var appliedScenarioID: String?
    @State private var summary = DebugHarnessHandlers().summary()

    /// Polls because the menu bar redraws on its own clock without notifying this window.
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    scenarioSection
                    Divider()
                    togglesSection
                    Divider()
                    readoutSection
                }
                .padding(16)
            }
        }
        .onReceive(tick) { _ in summary = handlers.summary() }
        .onAppear { summary = handlers.summary() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Debug harness").font(.headline)
                Text("Debug builds only — not compiled into Release.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Scenarios

    private var scenarioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Fake data")

            if !summary.hasSelectedCalendars {
                Label(
                    "No calendar is selected, so the menu bar stays on the app icon "
                        + "whatever is injected. Pick one on the Calendars pane first.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            Text(
                "Injects synthetic events into the running app. Scenarios are built "
                    + "relative to the moment you click, and then age normally — pick "
                    + "\"in 20 seconds\" and watch it become a running meeting."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            ForEach(DebugScenario.all) { scenario in
                scenarioRow(scenario)
            }
        }
    }

    private func scenarioRow(_ scenario: DebugScenario) -> some View {
        let isApplied = appliedScenarioID == scenario.id
        return Button {
            handlers.apply(scenario)
            appliedScenarioID = scenario.id
            summary = handlers.summary()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: isApplied ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isApplied ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(scenario.name).font(.system(size: 12, weight: .medium))
                    Text(scenario.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if isApplied {
                    // Re-applying rebases the scenario on now, replaying its transition.
                    Text("replay").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toggles

    /// Settings worth flipping while watching the menu bar.
    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Menu bar settings")

            Toggle("Join button", isOn: $showJoinAction)
            HStack(spacing: 6) {
                Text("Lead time").font(.system(size: 12))
                Stepper(
                    value: $joinActionLeadMinutes,
                    in: 0 ... 120
                ) {
                    Text(joinActionLeadMinutes == 0 ? "when it starts" : "\(joinActionLeadMinutes) min before")
                        .font(.system(size: 12))
                        .monospacedDigit()
                }
                .disabled(!showJoinAction)
            }

            HStack(spacing: 6) {
                Text("Countdown from").font(.system(size: 12))
                Stepper(value: $countdownLeadMinutes, in: 0 ... 720, step: 5) {
                    Text(countdownLeadMinutes == 0 ? "always" : "\(countdownLeadMinutes) min before")
                        .font(.system(size: 12))
                        .monospacedDigit()
                }
            }

            Toggle("Two-line layout", isOn: $twoLineLayout)
            Toggle("Bolden when imminent", isOn: $highlightImminent)

            Picker("Meeting progress", selection: $meetingProgressStyle) {
                Text("None").tag(MeetingProgressStyle.none.rawValue)
                Text("Underline").tag(MeetingProgressStyle.underline.rawValue)
                Text("Ring").tag(MeetingProgressStyle.ring.rawValue)
                Text("Capsule").tag(MeetingProgressStyle.capsule.rawValue)
                Text("Bar").tag(MeetingProgressStyle.bar.rawValue)
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 260)
        }
    }

    // MARK: - Readout

    /// What the menu bar actually drew.
    private var readoutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Rendered right now")

            readoutRow("Events", summary.isOverridden
                ? "\(summary.eventCount) (overridden)"
                : "\(summary.eventCount) (real calendar)")
            readoutRow("First line", summary.firstLine.isEmpty ? "—" : summary.firstLine)
            readoutRow("Second line", summary.secondLine.isEmpty ? "—" : summary.secondLine)
            readoutRow("Join label", summary.actionLabel.isEmpty ? "— (no chip)" : summary.actionLabel)
            readoutRow("Item width", String(format: "%.0f pt", summary.buttonWidth))
            readoutRow(
                "Chip target",
                summary.chipRect.map {
                    String(format: "x %.1f … %.1f  (w %.1f)", $0.minX, $0.maxX, $0.width)
                } ?? "none — a click opens the dropdown"
            )

            if summary.chipRect != nil {
                Label(
                    "Click the capsule in the menu bar: it should open "
                        + DebugScenario.meetingURL.absoluteString + " instead of the dropdown.",
                    systemImage: "cursorarrow.rays"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func readoutRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.secondary)
            .kerning(0.6)
    }
}
#endif
