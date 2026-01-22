import AppKit
import SwiftUI
import Combine

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        setupStatusItem()
        setupPopover()
        observeCountdownUpdates()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            updateButtonTitle(with: "Loading...")
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 450)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: StatusBarMenuView()
        )
    }

    private func observeCountdownUpdates() {
        Task { @MainActor in
            CountdownManager.shared.$currentState
                .receive(on: DispatchQueue.main)
                .sink { [weak self] snapshot in
                    self?.updateStatusBarDisplay(with: snapshot)
                }
                .store(in: &cancellables)
        }
    }

    private func updateStatusBarDisplay(with snapshot: CountdownSnapshot?) {
        guard let snapshot = snapshot else {
            updateButtonTitle(with: "Prayer")
            return
        }

        updateButtonTitle(with: snapshot.statusBarText)
    }

    private func updateButtonTitle(with title: String) {
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "moon.stars.fill", accessibilityDescription: "Prayer")
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.title = " \(title)"
        }
    }

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            if let button = statusItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }
}
