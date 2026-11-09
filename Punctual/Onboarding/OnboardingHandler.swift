//
//  OnboardingHandler.swift
//  MeetingBar
//
//  Holds the onboarding callbacks that `AuthorizationScreen` invokes, injected as an
//  environment object so no view reaches into `AppDelegate`.
//

import Foundation

/// Observable wrapper around the onboarding workflows. Created by `WindowCoordinator`
/// and injected into `OnboardingView` as an environment object.
@MainActor
final class OnboardingHandler: ObservableObject {
    var onProviderSelected:
        @MainActor (EventStoreProvider) async -> ProviderSelectionResult
    var onComplete:
        @MainActor (EventStoreProvider) async -> ProviderSelectionResult

    @Published var appModel: AppModel?

    init(
        onProviderSelected:
            @escaping @MainActor (EventStoreProvider) async -> ProviderSelectionResult,
        onComplete:
            @escaping @MainActor (EventStoreProvider) async -> ProviderSelectionResult
    ) {
        self.onProviderSelected = onProviderSelected
        self.onComplete = onComplete
    }
}
