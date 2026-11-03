import AppKit
import ApplicationServices
import DockGeometry

/// Ties the settings, the guard and the mover together.
final class DockLockController {
    enum Status: Equatable {
        case disabled
        case needsAccessibility
        case targetDisconnected
        case moving
        case locked(String)
        case edgeCovered(String)
        case moveFailed(String)
    }

    private enum Key {
        static let enabled = "lockEnabled"
        static let targetUUID = "targetDisplayUUID"
    }

    var onChange: (() -> Void)?
    private(set) var status: Status = .disabled {
        didSet { if status != oldValue { onChange?() } }
    }

    private let defaults = UserDefaults.standard
    private let guardian = DockGuard()
    private var timer: Timer?
    private var isMoving = false
    /// After a failed move, wait for a layout change or a manual retry instead of grabbing the cursor again.
    private var autoMoveSuspended = false

    var displays: [Display] { Display.current() }

    var isEnabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: Key.enabled)
            autoMoveSuspended = false
            refresh()
        }
    }

    var targetUUID: String? {
        get { defaults.string(forKey: Key.targetUUID) }
        set {
            defaults.set(newValue, forKey: Key.targetUUID)
            autoMoveSuspended = false
            refresh()
        }
    }

    func start() {
        if targetUUID == nil {
            let main = displays.first { CGDisplayIsMain($0.id) != 0 }
            defaults.set(main?.uuid, forKey: Key.targetUUID)
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.autoMoveSuspended = false
            self?.refresh()
        }

        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        promptForAccessibility()
        refresh()
    }

    func promptForAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func moveNow() {
        autoMoveSuspended = false
        refresh(forceMove: true)
    }

    func refresh(forceMove: Bool = false) {
        guard isEnabled else {
            guardian.stop()
            guardian.zones = []
            status = .disabled
            return
        }
        guard AXIsProcessTrusted(), guardian.start() else {
            guardian.stop()
            status = .needsAccessibility
            return
        }

        let displays = displays
        guard let target = displays.first(where: { $0.uuid == targetUUID }) else {
            guardian.zones = []
            status = .targetDisconnected
            return
        }

        let edge = DockPreferences.edge
        let bounds = displays.map(\.bounds)
        guardian.zones = DockGeometry.blockZones(target: target.bounds, displays: bounds, edge: edge)

        guard !isMoving else { return }

        let current = DockLocator.display(among: displays, edge: edge)
        if current?.uuid == target.uuid || displays.count < 2 {
            autoMoveSuspended = false
            status = .locked(target.name)
            return
        }

        let buttonsDown = NSEvent.pressedMouseButtons != 0
        guard forceMove || (!autoMoveSuspended && !buttonsDown) else { return }
        move(to: target, displays: displays, edge: edge)
    }

    private func move(to target: Display, displays: [Display], edge: DockEdge) {
        isMoving = true
        status = .moving
        DockMover.move(
            target: target,
            displays: displays,
            edge: edge,
            isOnTarget: {
                DockLocator.display(among: Display.current(), edge: edge)?.uuid == target.uuid
            },
            completion: { [weak self] outcome in
                guard let self else { return }
                self.isMoving = false
                switch outcome {
                case .moved:
                    self.status = .locked(target.name)
                case .failed(let edgeWasCovered):
                    self.autoMoveSuspended = true
                    self.status = edgeWasCovered ? .edgeCovered(target.name) : .moveFailed(target.name)
                }
            }
        )
    }
}
