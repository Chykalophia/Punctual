//
//  PresetNumberPicker.swift
//  Punctual
//
//  A "preset segments + Custom" control for numeric preferences.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import SwiftUI

/// A segmented control of preset numbers plus a "Custom" segment that reveals a stepper.
///
/// Selecting a preset writes it to `value`; "Custom" allows any value in `range`.
/// Presets outside `range` are dropped.
struct PresetNumberPicker: View {
    /// Tag for the "Custom" segment; `Int.min` never collides with a real value.
    private static let customTag = Int.min

    /// Preset values already filtered to `range`.
    private let presets: [Int]
    private let presetLabel: (Int) -> String
    private let customLabel: String
    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private let step: Int
    private let stepperLabel: (Int) -> String
    private let example: String?
    private let isEnabled: Bool

    /// Whether "Custom" is active. Seeded from the initial value, then sticky: stepping
    /// onto a preset value does not switch back to that segment.
    @State private var isCustom: Bool

    init(
        presets: [Int],
        presetLabel: @escaping (Int) -> String,
        customLabel: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        stepperLabel: @escaping (Int) -> String,
        example: String? = nil,
        isEnabled: Bool = true
    ) {
        let available = presets.filter { range.contains($0) }
        self.presets = available
        self.presetLabel = presetLabel
        self.customLabel = customLabel
        self._value = value
        self.range = range
        self.step = step
        self.stepperLabel = stepperLabel
        self.example = example
        self.isEnabled = isEnabled
        self._isCustom = State(initialValue: !available.contains(value.wrappedValue))
    }

    /// Presets write through to `value`; the Custom tag enters Custom mode without changing `value`.
    private var selection: Binding<Int> {
        Binding(
            get: { isCustom ? Self.customTag : value },
            set: { newValue in
                if newValue == Self.customTag {
                    isCustom = true
                } else {
                    isCustom = false
                    value = newValue
                }
            }
        )
    }

    var body: some View {
        Group {
            Picker("", selection: selection) {
                ForEach(presets, id: \.self) { preset in
                    Text(presetLabel(preset)).tag(preset)
                }
                Text(customLabel).tag(Self.customTag)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .preferenceIndent()
            .disabled(!isEnabled)

            if isCustom {
                HStack {
                    Spacer()
                    Stepper(value: $value, in: range, step: step) {
                        Text(stepperLabel(value)).monospacedDigit()
                    }
                    .fixedSize()
                }
                .preferenceIndent()
                .disabled(!isEnabled)
            }

            if let example {
                Text(example)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .preferenceIndent()
            }
        }
    }
}
