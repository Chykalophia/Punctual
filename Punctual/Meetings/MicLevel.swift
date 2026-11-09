//
//  MicLevel.swift
//  Punctual
//
//  Normalizes a dBFS reading (`AVCaptureAudioChannel.averagePowerLevel`, roughly
//  -160…0) to 0…1 for the preview meter. No AVFoundation, so it is unit-testable.
//
//  Created for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import Foundation

/// Normalizes microphone power readings for the preview meter.
public enum MicLevel {
    /// Reading at or below which the meter is empty; a common coarse noise floor.
    public static let defaultFloorDecibels: Float = -60

    /// Maps a `decibels` reading (dBFS, ≤ 0 at full scale) to a clamped 0…1
    /// value, linear in decibels between `floorDecibels` (→ 0) and 0 dB (→ 1).
    ///
    /// - Non-finite input (NaN / -inf silence) returns 0.
    /// - A non-negative `floorDecibels` is clamped to -1 so the range never
    ///   collapses or divides by zero.
    public static func normalized(
        decibels: Float,
        floorDecibels: Float = defaultFloorDecibels
    ) -> Float {
        guard decibels.isFinite else { return 0 }
        let floor = min(floorDecibels, -1)
        if decibels <= floor { return 0 }
        if decibels >= 0 { return 1 }
        return (decibels - floor) / -floor
    }
}
