import CoreGraphics
import DockGeometry
import Foundation

/// Watches cursor movement and keeps it off the edges that would pull the Dock away.
final class DockGuard {
    var zones: [BlockZone] = []

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// Returns false when macOS refuses the tap, which means Accessibility access is missing.
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }

        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                let owner = Unmanaged<DockGuard>.fromOpaque(refcon!).takeUnretainedValue()
                return owner.handle(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        // Without this, each warp freezes the cursor for a quarter of a second.
        CGEventSource(stateID: .combinedSessionState)?.localEventsSuppressionInterval = 0

        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CFMachPortInvalidate(tap)
        self.tap = nil
        self.source = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if let allowed = DockGeometry.clamped(event.location, zones: zones) {
            CGWarpMouseCursorPosition(allowed)
            event.location = allowed
        }
        return Unmanaged.passUnretained(event)
    }
}
