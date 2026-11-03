import AppKit
import ApplicationServices
import DockGeometry

/// Finds the display currently showing the Dock.
enum DockLocator {
    private static let minimumInset: CGFloat = 8

    static func display(among displays: [Display], edge: DockEdge) -> Display? {
        if let reserved = displays.first(where: { $0.dockInset(edge: edge) >= minimumInset }) {
            return reserved
        }
        // An auto-hidden Dock reserves no space, so ask the Dock itself where it is.
        guard let rect = dockListRect() else { return nil }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return displays.first { $0.bounds.contains(center) }
    }

    private static func dockListRect() -> CGRect? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return nil
        }
        let app = AXUIElementCreateApplication(dock.processIdentifier)
        var children: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &children) == .success,
              let elements = children as? [AXUIElement],
              let list = elements.first(where: { role(of: $0) == kAXListRole as String })
        else { return nil }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard let positionValue = axValue(of: list, kAXPositionAttribute),
              let sizeValue = axValue(of: list, kAXSizeAttribute),
              AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func axValue(of element: AXUIElement, _ attribute: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        return (value as! AXValue)
    }
}
