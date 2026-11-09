//
//  QuickActionsMenu.swift
//  Punctual
//
//  The compact menu shown when the status item is right-clicked. The panel's
//  "More actions" flyout mirrors it.
//
//  Original work for Punctual by Peter Krzyzek / Chykalophia, 2026.
//

import AppKit

enum QuickActionsMenu {
    /// Builds the menu.
    ///
    /// - Parameter target: Receiver of the `StatusBarItemController` @objc actions.
    @MainActor
    static func build(target: AnyObject, state: StatusBarMenuState) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let join = item(
            "status_bar_quick_action_join_next",
            #selector(StatusBarItemController.joinNextMeeting),
            target: target
        )
        join.isEnabled = state.nextEvent?.meetingLink != nil
        menu.addItem(join)

        menu.addItem(item(
            "status_bar_quick_action_create_meeting",
            #selector(StatusBarItemController.createMeetingAction),
            target: target
        ))
        // In-app event creation writes through EventKit only; hidden for other providers.
        if state.activeProvider == .macOSEventKit {
            menu.addItem(item(
                "status_bar_quick_action_new_event",
                #selector(StatusBarItemController.newEventAction),
                target: target
            ))
        }
        menu.addItem(item(
            "status_bar_quick_action_copy_agenda",
            #selector(StatusBarItemController.copyTodayAgendaAction),
            target: target
        ))

        menu.addItem(.separator())

        menu.addItem(item(
            "status_bar_quick_action_open_calendar",
            #selector(StatusBarItemController.openCalendarAction),
            target: target
        ))
        menu.addItem(item(
            "status_bar_quick_action_world_clock",
            #selector(StatusBarItemController.openWorldClockAction),
            target: target
        ))
        menu.addItem(item(
            "status_bar_quick_action_camera_check",
            #selector(StatusBarItemController.openCameraPreviewAction),
            target: target
        ))
        menu.addItem(item(
            "status_bar_quick_action_refresh",
            #selector(StatusBarItemController.handleManualRefresh),
            target: target
        ))
        menu.addItem(item(
            "status_bar_quick_action_preferences",
            #selector(StatusBarItemController.openPreferencesAction),
            target: target
        ))
        menu.addItem(item(
            "status_bar_quick_action_check_updates",
            #selector(StatusBarItemController.checkForUpdatesAction),
            target: target
        ))

        menu.addItem(.separator())

        menu.addItem(item(
            "status_bar_quick_action_quit",
            #selector(StatusBarItemController.quitAction),
            target: target
        ))

        return menu
    }

    @MainActor
    private static func item(
        _ titleKey: String,
        _ action: Selector,
        target: AnyObject
    ) -> NSMenuItem {
        let menuItem = NSMenuItem(title: titleKey.loco(), action: action, keyEquivalent: "")
        menuItem.target = target
        return menuItem
    }
}
