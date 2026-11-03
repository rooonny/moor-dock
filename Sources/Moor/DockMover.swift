import CoreGraphics
import DockGeometry
import Foundation

/// Moves the Dock by pressing the cursor against the target display's edge, then putting it back.
enum DockMover {
    enum Outcome {
        case moved
        /// The Dock stayed put. `edgeWasCovered` means no part of the target's edge is free.
        case failed(edgeWasCovered: Bool)
    }

    private static let approachDistance: CGFloat = 40
    private static let pressAttempts = 60
    private static let stepDelay: TimeInterval = 0.02

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

        DispatchQueue.global(qos: .userInitiated).async {
            let original = CGEvent(source: nil)?.location
            let source = CGEventSource(stateID: .hidSystemState)
            source?.localEventsSuppressionInterval = 0
            CGAssociateMouseAndMouseCursorPosition(0)

            press(toward: push.point, edge: edge, source: source)

            var moved = false
            for attempt in 0..<pressAttempts {
                post(at: push.point, edge: edge, source: source)
                Thread.sleep(forTimeInterval: stepDelay)
                if attempt % 10 == 9, DispatchQueue.main.sync(execute: isOnTarget) {
                    moved = true
                    break
                }
            }

            if let original {
                CGWarpMouseCursorPosition(original)
            }
            CGAssociateMouseAndMouseCursorPosition(1)

            // The Dock can finish sliding in after the cursor has gone.
            Thread.sleep(forTimeInterval: 0.6)
            let settled = moved || DispatchQueue.main.sync(execute: isOnTarget)
            DispatchQueue.main.async {
                completion(settled ? .moved : .failed(edgeWasCovered: !push.isExposed))
            }
        }
    }

    private static func press(toward point: CGPoint, edge: DockEdge, source: CGEventSource?) {
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
