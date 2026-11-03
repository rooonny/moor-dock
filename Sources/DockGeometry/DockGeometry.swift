import CoreGraphics

/// The screen edge the Dock is pinned to (`com.apple.dock orientation`).
public enum DockEdge: String, Sendable {
    case bottom, left, right
}

/// A band along a display edge where the cursor is not allowed to rest.
public struct BlockZone: Equatable, Sendable {
    public let rect: CGRect
    public let edge: DockEdge

    public init(rect: CGRect, edge: DockEdge) {
        self.rect = rect
        self.edge = edge
    }
}

/// Where to press the cursor so the Dock moves to a display.
public struct PushPoint: Equatable, Sendable {
    public let point: CGPoint
    /// False when another display covers the whole edge, so nothing stops the cursor there.
    public let isExposed: Bool

    public init(point: CGPoint, isExposed: Bool) {
        self.point = point
        self.isExposed = isExposed
    }
}

/// All functions use global display coordinates: origin at the top-left of the main display, y grows downward.
public enum DockGeometry {
    /// Parts of a display's edge with no neighbouring display beyond them.
    /// The cursor stops at these parts, which is what lets it summon the Dock.
    public static func exposedSegments(
        of display: CGRect,
        among displays: [CGRect],
        edge: DockEdge
    ) -> [ClosedRange<CGFloat>] {
        let span: ClosedRange<CGFloat> = edge == .bottom
            ? display.minX...display.maxX
            : display.minY...display.maxY

        let covers = displays
            .filter { $0 != display && touches($0, display, edge: edge) }
            .map { edge == .bottom ? ($0.minX, $0.maxX) : ($0.minY, $0.maxY) }
            .sorted { $0.0 < $1.0 }

        var segments: [ClosedRange<CGFloat>] = []
        var cursor = span.lowerBound
        for (start, end) in covers {
            if start > cursor {
                segments.append(cursor...min(start, span.upperBound))
            }
            cursor = max(cursor, end)
        }
        if cursor < span.upperBound {
            segments.append(cursor...span.upperBound)
        }
        return segments
    }

    /// Bands on every display except the target where reaching the edge would pull the Dock away.
    public static func blockZones(
        target: CGRect,
        displays: [CGRect],
        edge: DockEdge,
        thickness: CGFloat = 3
    ) -> [BlockZone] {
        displays.filter { $0 != target }.flatMap { display in
            exposedSegments(of: display, among: displays, edge: edge).map { segment in
                BlockZone(rect: band(on: display, segment: segment, edge: edge, thickness: thickness), edge: edge)
            }
        }
    }

    /// The cursor position to use instead of `point`, or nil when `point` is allowed.
    public static func clamped(_ point: CGPoint, zones: [BlockZone]) -> CGPoint? {
        guard let zone = zones.first(where: { contains($0.rect, point) }) else { return nil }
        switch zone.edge {
        case .bottom: return CGPoint(x: point.x, y: zone.rect.minY - 1)
        case .left: return CGPoint(x: zone.rect.maxX + 1, y: point.y)
        case .right: return CGPoint(x: zone.rect.minX - 1, y: point.y)
        }
    }

    /// The middle of the longest exposed part of the target's edge.
    public static func pushPoint(target: CGRect, displays: [CGRect], edge: DockEdge) -> PushPoint {
        let segments = exposedSegments(of: target, among: displays, edge: edge)
        let longest = segments.max { length($0) < length($1) }
        let middle = longest.map { ($0.lowerBound + $0.upperBound) / 2 }
            ?? (edge == .bottom ? target.midX : target.midY)

        let point: CGPoint
        switch edge {
        case .bottom: point = CGPoint(x: middle, y: target.maxY - 1)
        case .left: point = CGPoint(x: target.minX, y: middle)
        case .right: point = CGPoint(x: target.maxX - 1, y: middle)
        }
        return PushPoint(point: point, isExposed: longest != nil)
    }

    private static func touches(_ other: CGRect, _ display: CGRect, edge: DockEdge) -> Bool {
        switch edge {
        case .bottom:
            return abs(other.minY - display.maxY) < 1 && other.minX < display.maxX && other.maxX > display.minX
        case .left:
            return abs(other.maxX - display.minX) < 1 && other.minY < display.maxY && other.maxY > display.minY
        case .right:
            return abs(other.minX - display.maxX) < 1 && other.minY < display.maxY && other.maxY > display.minY
        }
    }

    private static func band(
        on display: CGRect,
        segment: ClosedRange<CGFloat>,
        edge: DockEdge,
        thickness: CGFloat
    ) -> CGRect {
        let extent = segment.upperBound - segment.lowerBound
        switch edge {
        case .bottom:
            return CGRect(x: segment.lowerBound, y: display.maxY - thickness, width: extent, height: thickness)
        case .left:
            return CGRect(x: display.minX, y: segment.lowerBound, width: thickness, height: extent)
        case .right:
            return CGRect(x: display.maxX - thickness, y: segment.lowerBound, width: thickness, height: extent)
        }
    }

    private static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x <= rect.maxX && point.y >= rect.minY && point.y <= rect.maxY
    }

    private static func length(_ segment: ClosedRange<CGFloat>) -> CGFloat {
        segment.upperBound - segment.lowerBound
    }
}
