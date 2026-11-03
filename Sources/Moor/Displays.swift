import AppKit
import DockGeometry

struct Display: Equatable {
    let id: CGDirectDisplayID
    let uuid: String
    let name: String
    /// Global display coordinates (y grows downward).
    let bounds: CGRect
    /// AppKit coordinates, used to read the space the Dock reserves.
    let frame: CGRect
    let visibleFrame: CGRect

    static func current() -> [Display] {
        NSScreen.screens.compactMap { screen in
            let key = NSDeviceDescriptionKey("NSScreenNumber")
            guard let id = screen.deviceDescription[key] as? CGDirectDisplayID,
                  let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
                  let uuid = CFUUIDCreateString(nil, cfUUID) as String?
            else { return nil }
            return Display(
                id: id,
                uuid: uuid,
                name: screen.localizedName,
                bounds: CGDisplayBounds(id),
                frame: screen.frame,
                visibleFrame: screen.visibleFrame
            )
        }
    }

    /// Space reserved at the Dock's edge. Stays near zero when the Dock lives elsewhere or auto-hides.
    func dockInset(edge: DockEdge) -> CGFloat {
        switch edge {
        case .bottom: return visibleFrame.minY - frame.minY
        case .left: return visibleFrame.minX - frame.minX
        case .right: return frame.maxX - visibleFrame.maxX
        }
    }
}

enum DockPreferences {
    static var edge: DockEdge {
        let value = UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation")
        return value.flatMap(DockEdge.init(rawValue:)) ?? .bottom
    }
}
