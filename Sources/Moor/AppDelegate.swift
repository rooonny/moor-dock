import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let controller = DockLockController()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item

        controller.onChange = { [weak self] in self?.updateIcon() }
        controller.start()
        updateIcon()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())

        let lock = item("Lock Dock", #selector(toggleLock))
        lock.state = controller.isEnabled ? .on : .off
        menu.addItem(lock)

        let displays = controller.displays
        let target = NSMenuItem(title: "Lock to Display", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for display in displays {
            let entry = item(display.name, #selector(selectDisplay(_:)))
            entry.representedObject = display.uuid
            entry.state = display.uuid == controller.targetUUID ? .on : .off
            submenu.addItem(entry)
        }
        target.submenu = submenu
        menu.addItem(target)

        let move = item("Move Dock Now", #selector(moveNow))
        move.isEnabled = controller.isEnabled && controller.status != .needsAccessibility
        menu.addItem(move)
        menu.addItem(.separator())

        if controller.status == .needsAccessibility {
            menu.addItem(item("Open Accessibility Settings…", #selector(openAccessibility)))
        }

        let login = item("Open at Login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Moor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private var statusText: String {
        switch controller.status {
        case .disabled: return "Lock is off"
        case .needsAccessibility: return "Needs Accessibility access"
        case .targetDisconnected: return "Chosen display is not connected"
        case .moving: return "Moving Dock…"
        case .locked(let name): return "Dock locked to \(name)"
        case .edgeCovered(let name): return "Couldn't move Dock: \(name)'s edge is fully covered"
        case .moveFailed(let name): return "Couldn't move Dock to \(name)"
        }
    }

    private func updateIcon() {
        let symbol: String
        switch controller.status {
        case .locked: symbol = "dock.rectangle"
        case .moving: symbol = "arrow.up.and.down.square"
        case .disabled: symbol = "lock.open"
        case .needsAccessibility, .targetDisconnected, .edgeCovered, .moveFailed: symbol = "exclamationmark.triangle"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Moor")
        image?.isTemplate = true
        statusItem?.button?.image = image
        statusItem?.button?.toolTip = statusText
    }

    @objc private func toggleLock() {
        controller.setEnabled(!controller.isEnabled)
    }

    @objc private func selectDisplay(_ sender: NSMenuItem) {
        guard let uuid = sender.representedObject as? String else { return }
        controller.selectTarget(uuid: uuid)
    }

    @objc private func moveNow() {
        controller.moveNow()
    }

    @objc private func openAccessibility() {
        controller.promptForAccessibility()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
