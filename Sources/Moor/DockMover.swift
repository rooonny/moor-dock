import AppKit
import DockGeometry

/// Moves the Dock by pressing the cursor against the target display's edge, then putting it back.
enum DockMover {
    enum Outcome {
        case moved
        /// The Dock stayed put. `edgeWasCovered` means no part of the target's edge is free.
        case failed(edgeWasCovered: Bool)
    }

    private static let maxAttempts = 3
    private static let pauseBetweenAttempts: TimeInterval = 1
    private static let approachDistance: CGFloat = 40
    private static let pressSteps = 60
    private static let stepDelay: TimeInterval = 0.02
    /// The Dock can finish sliding in after the cursor has gone.
    private static let settleDelay: TimeInterval = 0.6

    /// Runs off the main thread so the event tap keeps responding. `isOnTarget` is called on the main thread.
    static func move(
        target: Display,
        displays: [Display],
        edge: DockEdge,
        isOnTarget: @escaping () -> Bool,
        completion: @escaping (Outcome) -> Void
    ) {
        let push = DockGeometry.pushPoint(
            target: target.bounds,
            displays: displays.map(\.bounds),
            edge: edge
        )
        log.notice("Moving Dock to \(target.name): edge \(edge.rawValue), push point \(push.point.x),\(push.point.y), exposed \(push.isExposed)")

        DispatchQueue.global(qos: .userInitiated).async {
            var moved = false
            for attempt in 1...maxAttempts where !moved {
                if attempt > 1 {
                    Thread.sleep(forTimeInterval: pauseBetweenAttempts)
                    // Don't take the cursor away in the middle of a drag.
                    while NSEvent.pressedMouseButtons != 0 {
                        Thread.sleep(forTimeInterval: 0.2)
                    }
                }
                moved = press(at: push.point, edge: edge, isOnTarget: isOnTarget)
                log.notice("Attempt \(attempt) of \(maxAttempts): \(moved ? "moved" : "no change")")
            }
            DispatchQueue.main.async {
                completion(moved ? .moved : .failed(edgeWasCovered: !push.isExposed))
            }
        }
    }

    private static func press(at point: CGPoint, edge: DockEdge, isOnTarget: @escaping () -> Bool) -> Bool {
        let original = CGEvent(source: nil)?.location
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0
        CGAssociateMouseAndMouseCursorPosition(0)

        approach(point, edge: edge, source: source)

        var moved = false
        for step in 0..<pressSteps {
            post(at: point, edge: edge, source: source)
            Thread.sleep(forTimeInterval: stepDelay)
            if step % 10 == 9, DispatchQueue.main.sync(execute: isOnTarget) {
                moved = true
                break
            }
        }

        if let original {
            CGWarpMouseCursorPosition(original)
        }
        CGAssociateMouseAndMouseCursorPosition(1)

        if moved { return true }
        Thread.sleep(forTimeInterval: settleDelay)
        return DispatchQueue.main.sync(execute: isOnTarget)
    }

    private static func approach(_ point: CGPoint, edge: DockEdge, source: CGEventSource?) {
        let inward = inwardUnit(edge)
        var distance = approachDistance
        while distance > 0 {
            let step = CGPoint(x: point.x + inward.x * distance, y: point.y + inward.y * distance)
            post(at: step, edge: edge, source: source)
            Thread.sleep(forTimeInterval: stepDelay / 2)
            distance -= 4
        }
    }

    private static func post(at point: CGPoint, edge: DockEdge, source: CGEventSource?) {
        CGWarpMouseCursorPosition(point)
        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) else { return }
        let inward = inwardUnit(edge)
        event.setIntegerValueField(.mouseEventDeltaX, value: Int64(-inward.x * 4))
        event.setIntegerValueField(.mouseEventDeltaY, value: Int64(-inward.y * 4))
        event.post(tap: .cghidEventTap)
    }

    private static func inwardUnit(_ edge: DockEdge) -> CGPoint {
        switch edge {
        case .bottom: return CGPoint(x: 0, y: -1)
        case .left: return CGPoint(x: 1, y: 0)
        case .right: return CGPoint(x: -1, y: 0)
        }
    }
}
