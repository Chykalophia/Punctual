//
//  CameraPreviewController.swift
//  Punctual
//
//  AVFoundation service for the pre-call preview: a live camera feed and a microphone
//  level meter. Preview only; nothing is recorded. Camera and microphone access are
//  requested only when the preview opens, never at launch.
//
//  Created for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit
import AVFoundation
import CoreMedia
import Foundation

/// Per-device authorization state shown by the preview view.
enum CameraPreviewAccess: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted

    static func from(_ status: AVAuthorizationStatus) -> CameraPreviewAccess {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }
}

/// Sendable descriptor for a capture device, so device lists can cross from the
/// session queue to the main actor.
struct CameraDeviceOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}

/// Owns the preview window's `AVCaptureSession`. UI state is main-actor; session
/// mutation runs on a private serial queue so `startRunning()` never blocks the UI.
/// Capture members are `nonisolated(unsafe)` because only that queue touches them.
@MainActor
final class CameraPreviewController: NSObject, ObservableObject,
    AVCaptureAudioDataOutputSampleBufferDelegate {
    /// The capture session the preview layer renders. Read on the main actor by
    /// the view; mutated only on `sessionQueue`.
    nonisolated(unsafe) let session = AVCaptureSession()

    @Published private(set) var cameraAccess: CameraPreviewAccess = .notDetermined
    @Published private(set) var micAccess: CameraPreviewAccess = .notDetermined
    /// Normalized 0…1 microphone level; 0 while metering is unavailable.
    @Published private(set) var micLevel: Float = 0
    @Published private(set) var videoDevices: [CameraDeviceOption] = []
    @Published private(set) var audioDevices: [CameraDeviceOption] = []
    @Published var selectedVideoDeviceID: String?
    @Published var selectedAudioDeviceID: String?
    /// True when camera access is granted but no video device is present
    /// (e.g. a Mac mini with no built-in or attached camera).
    @Published private(set) var hasNoCamera = false
    @Published private(set) var isRunning = false

    nonisolated(unsafe) private var videoInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var audioInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private let audioOutput = AVCaptureAudioDataOutput()

    nonisolated private let sessionQueue = DispatchQueue(
        label: "com.chykalophia.Punctual.camera-session"
    )
    nonisolated private let audioSampleQueue = DispatchQueue(
        label: "com.chykalophia.Punctual.mic-samples"
    )

    // MARK: - Lifecycle

    /// Requests access, then enumerates devices and starts the session on the session queue.
    func startPreview() async {
        let access = await requestAccess()
        let videoID = selectedVideoDeviceID
        let audioID = selectedAudioDeviceID
        sessionQueue.async { [weak self] in
            self?.reloadDevicesAndConfigure(
                cameraGranted: access.camera,
                micGranted: access.mic,
                requestedVideoID: videoID,
                requestedAudioID: audioID
            )
        }
    }

    /// Stops the session and releases the camera and microphone, turning off the camera light.
    func stop() {
        micLevel = 0
        isRunning = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            if self.session.outputs.contains(self.audioOutput) {
                self.audioOutput.setSampleBufferDelegate(nil, queue: nil)
                self.session.removeOutput(self.audioOutput)
            }
            self.session.commitConfiguration()
            self.videoInput = nil
            self.audioInput = nil
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    /// Releases the hardware if `stop()` was never reached.
    deinit {
        session.stopRunning()
    }

    // MARK: - Device switching

    func selectVideoDevice(id: String) {
        guard id != selectedVideoDeviceID else { return }
        selectedVideoDeviceID = id
        reconfigure()
    }

    func selectAudioDevice(id: String) {
        guard id != selectedAudioDeviceID else { return }
        selectedAudioDeviceID = id
        reconfigure()
    }

    private func reconfigure() {
        let cameraGranted = cameraAccess == .authorized
        let micGranted = micAccess == .authorized
        let videoID = selectedVideoDeviceID
        let audioID = selectedAudioDeviceID
        sessionQueue.async { [weak self] in
            self?.reloadDevicesAndConfigure(
                cameraGranted: cameraGranted,
                micGranted: micGranted,
                requestedVideoID: videoID,
                requestedAudioID: audioID
            )
        }
    }

    // MARK: - Access (opt-in)

    /// Requests camera and microphone access independently and publishes the results.
    /// The only place these permission prompts are triggered.
    @discardableResult
    func requestAccess() async -> (camera: Bool, mic: Bool) {
        let camera = await Self.requestAccess(for: .video)
        let mic = await Self.requestAccess(for: .audio)
        cameraAccess = CameraPreviewAccess.from(AVCaptureDevice.authorizationStatus(for: .video))
        micAccess = CameraPreviewAccess.from(AVCaptureDevice.authorizationStatus(for: .audio))
        return (camera, mic)
    }

    private static func requestAccess(for mediaType: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: mediaType)
        default:
            return false
        }
    }

    // MARK: - System Settings affordances

    func openCameraSettings() {
        NSWorkspace.shared.open(Links.cameraPreferences)
    }

    func openMicrophoneSettings() {
        NSWorkspace.shared.open(Links.microphonePreferences)
    }

    // MARK: - Session configuration (session queue)

    nonisolated private func reloadDevicesAndConfigure(
        cameraGranted: Bool,
        micGranted: Bool,
        requestedVideoID: String?,
        requestedAudioID: String?
    ) {
        let discoveredVideo = cameraGranted ? Self.discoverVideoDevices() : []
        let discoveredAudio = micGranted ? Self.discoverAudioDevices() : []

        let chosenVideo = discoveredVideo.first { $0.uniqueID == requestedVideoID }
            ?? discoveredVideo.first
        let chosenAudio = discoveredAudio.first { $0.uniqueID == requestedAudioID }
            ?? discoveredAudio.first

        configureSession(video: chosenVideo, audio: chosenAudio)
        if !session.isRunning {
            session.startRunning()
        }

        let videoOptions = discoveredVideo.map {
            CameraDeviceOption(id: $0.uniqueID, name: $0.localizedName)
        }
        let audioOptions = discoveredAudio.map {
            CameraDeviceOption(id: $0.uniqueID, name: $0.localizedName)
        }
        let chosenVideoID = chosenVideo?.uniqueID
        let chosenAudioID = chosenAudio?.uniqueID
        let running = session.isRunning

        Task { @MainActor in
            self.videoDevices = videoOptions
            self.audioDevices = audioOptions
            self.selectedVideoDeviceID = chosenVideoID
            self.selectedAudioDeviceID = chosenAudioID
            self.hasNoCamera = cameraGranted && videoOptions.isEmpty
            self.isRunning = running
        }
    }

    /// Rebuilds inputs and outputs inside one begin/commit, so the session never sees a
    /// half-configured graph.
    nonisolated private func configureSession(
        video: AVCaptureDevice?,
        audio: AVCaptureDevice?
    ) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let videoInput {
            session.removeInput(videoInput)
            self.videoInput = nil
        }
        if let audioInput {
            session.removeInput(audioInput)
            self.audioInput = nil
        }

        if let video {
            do {
                let input = try AVCaptureDeviceInput(device: video)
                if session.canAddInput(input) {
                    session.addInput(input)
                    videoInput = input
                }
            } catch {
                PunctualLogger.camera.error(
                    "Camera input add failed: \(String(describing: error), privacy: .public)"
                )
            }
        }

        if let audio {
            do {
                let input = try AVCaptureDeviceInput(device: audio)
                if session.canAddInput(input) {
                    session.addInput(input)
                    audioInput = input
                }
            } catch {
                PunctualLogger.camera.error(
                    "Microphone input add failed: \(String(describing: error), privacy: .public)"
                )
            }
        }

        // The audio output is attached only with a mic input; its delivery keeps
        // `averagePowerLevel` updated. Buffers are never stored.
        if audioInput != nil {
            if !session.outputs.contains(audioOutput), session.canAddOutput(audioOutput) {
                session.addOutput(audioOutput)
                audioOutput.setSampleBufferDelegate(self, queue: audioSampleQueue)
            }
        } else if session.outputs.contains(audioOutput) {
            audioOutput.setSampleBufferDelegate(nil, queue: nil)
            session.removeOutput(audioOutput)
        }
    }

    nonisolated private static func discoverVideoDevices() -> [AVCaptureDevice] {
        var types: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        if #available(macOS 14.0, *) {
            types.append(.external)
            types.append(.continuityCamera)
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        var devices = discovery.devices
        // Include the default device so external-only webcam setups get a preview.
        if let fallback = AVCaptureDevice.default(for: .video),
            !devices.contains(where: { $0.uniqueID == fallback.uniqueID }) {
            devices.insert(fallback, at: 0)
        }
        return devices
    }

    nonisolated private static func discoverAudioDevices() -> [AVCaptureDevice] {
        var devices: [AVCaptureDevice] = []
        if #available(macOS 14.0, *) {
            devices = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone],
                mediaType: .audio,
                position: .unspecified
            ).devices
        }
        if let fallback = AVCaptureDevice.default(for: .audio),
            !devices.contains(where: { $0.uniqueID == fallback.uniqueID }) {
            devices.insert(fallback, at: 0)
        }
        return devices
    }

    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Average power (dBFS) is read off the connection; the buffer is not read or retained.
        let decibels = connection.audioChannels.first?.averagePowerLevel ?? -160
        let level = MicLevel.normalized(decibels: decibels)
        Task { @MainActor in
            self.micLevel = level
        }
    }
}
