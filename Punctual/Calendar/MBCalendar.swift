//
//  MBCalendar.swift
//  MeetingBar
//
//  Created by Andrii Leitsius on 09.04.2022.
//  Copyright © 2022 Andrii Leitsius. All rights reserved.
//

import AppKit

public struct MBCalendar: Hashable, Sendable {
    let title: String
    let id: String
    /// Display-only account name as the provider reports it; use `provider` to identify the store.
    let source: String
    let email: String?
    let color: NSColor
    /// The connected source that produced this calendar, used to route fetches and pick dedup survivors.
    let provider: EventStoreProvider

    init(
        title: String,
        id: String,
        source: String?,
        email: String?,
        color: NSColor,
        provider: EventStoreProvider = .macOSEventKit
    ) {
        self.title = title
        self.id = id
        self.source = source ?? "unknown"
        self.email = email
        self.color = color
        self.provider = provider
    }
}
