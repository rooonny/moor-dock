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
        static let targetVendor = "targetDisplayVendor"
        static let targetModel = "targetDisplayModel"
        static let targetSerial = "targetDisplaySerial"
    }

    /// Displays can take a moment to settle after waking or changing layout.
    private static let settleAfterScreenChange: TimeInterval = 3
    /// Lets a menu finish closing, since a move takes over the cursor.
    private static let menuCloseDelay: TimeInterval = 0.4

    var onChange: (() -> Void)?
    private(set) var status: Status = .disabled {
        didSet {
            guard status != oldValue else { return }
            log.notice("Status: \(String(describing: self.status))")
            onChange?()
        }
    }

    private let defaults = UserDefaults.standard
    private let guardian = DockGuard()
    private var timer: Timer?
    private var isMoving = false
    /// After a failed move, wait for a layout change or a manual retry instead of grabbing the cursor again.
    private var autoMoveSuspended = false
    private var noAutoMoveBefore = Date.distantPast

    var displays: [Display] { Display.current() }

    var isEnabled: Bool {
        defaults.object(forKey: Key.enabled) as? Bool ?? true
    }

    var targetUUID: String? {
        defaults.string(forKey: Key.targetUUID)
    }

    private var savedTarget: DisplayIdentity? {
        targetUUID.map {
            DisplayIdentity(
                uuid: $0,
                vendor: UInt32(truncatingIfNeeded: defaults.integer(forKey: Key.targetVendor)),
                model: UInt32(truncatingIfNeeded: defaults.integer(forKey: Key.targetModel)),
                serial: UInt32(truncatingIfNeeded: defaults.integer(forKey: Key.targetSerial))
            )
        }
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Key.enabled)
        refreshAfterMenuCloses()
    }

    func selectTarget(uuid: String) {
        guard let display = displays.first(where: { $0.uuid == uuid }) else { return }
        save(target: display.identity)
        refreshAfterMenuCloses()
    }

    func moveNow() {
        refreshAfterMenuCloses(forceMove: true)
    }

    func start() {
        if targetUUID == nil, let main = displays.first(where: { CGDisplayIsMain($0.id) != 0 }) {
            save(target: main.identity)
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.screensChanged("layout changed")
        }

        let workspace = NSWorkspace.shared.notificationCenter
        let wakeEvents: [(Notification.Name, String)] = [
            (NSWorkspace.didWakeNotification, "Mac woke"),
            (NSWorkspace.screensDidWakeNotification, "screens woke"),
            (NSWorkspace.sessionDidBecomeActiveNotification, "session became active"),
        ]
        for (name, reason) in wakeEvents {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.screensChanged(reason)
            }
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

    private func screensChanged(_ reason: String) {
        log.notice("Screens changed: \(reason)")
        autoMoveSuspended = false
        noAutoMoveBefore = Date().addingTimeInterval(Self.settleAfterScreenChange)
        refresh()
    }

    private func refreshAfterMenuCloses(forceMove: Bool = false) {
        autoMoveSuspended = false
        noAutoMoveBefore = Date().addingTimeInterval(Self.menuCloseDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.menuCloseDelay) { [weak self] in
            self?.refresh(forceMove: forceMove)
        }
    }

    private func save(target: DisplayIdentity) {
        defaults.set(target.uuid, forKey: Key.targetUUID)
        defaults.set(Int(target.vendor), forKey: Key.targetVendor)
        defaults.set(Int(target.model), forKey: Key.targetModel)
        defaults.set(Int(target.serial), forKey: Key.targetSerial)
    }

    private func refresh(forceMove: Bool = false) {
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
        guard let saved = savedTarget,
              let identity = saved.match(among: displays.map(\.identity)),
              let target = displays.first(where: { $0.identity == identity })
        else {
            guardian.zones = []
            status = .targetDisconnected
            return
        }
        if identity != saved {
            if identity.uuid != saved.uuid {
                log.notice("Recognised \(target.name) under a new display ID")
            }
            save(target: identity)
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

        let isReady = !autoMoveSuspended && Date() >= noAutoMoveBefore && NSEvent.pressedMouseButtons == 0
        guard forceMove || isReady else { return }
        log.notice("Dock found on \(current?.name ?? "unknown display"), expected on \(target.name)")
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
