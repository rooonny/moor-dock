import CoreGraphics
import Testing
@testable import DockGeometry

// A 2560x1440 monitor with a 1512x982 laptop centred underneath it.
private let monitor = CGRect(x: 0, y: 0, width: 2560, height: 1440)
private let laptop = CGRect(x: 539, y: 1440, width: 1512, height: 982)

@Test func monitorBottomIsExposedOnBothSidesOfTheLaptop() {
    let segments = DockGeometry.exposedSegments(of: monitor, among: [monitor, laptop], edge: .bottom)
    #expect(segments == [0...539, 2051...2560])
}

@Test func laptopBottomIsFullyExposed() {
    let segments = DockGeometry.exposedSegments(of: laptop, among: [monitor, laptop], edge: .bottom)
    #expect(segments == [539...2051])
}

@Test func sameWidthStackHasNoExposedEdge() {
    let below = CGRect(x: 0, y: 1440, width: 2560, height: 1440)
    #expect(DockGeometry.exposedSegments(of: monitor, among: [monitor, below], edge: .bottom).isEmpty)
}

@Test func offsetDisplaysLeaveOneSegment() {
    let below = CGRect(x: 2000, y: 1440, width: 1512, height: 982)
    #expect(DockGeometry.exposedSegments(of: monitor, among: [monitor, below], edge: .bottom) == [0...2000])
}

@Test func twoNeighboursSplitTheEdge() {
    let a = CGRect(x: 100, y: 1440, width: 500, height: 500)
    let b = CGRect(x: 1000, y: 1440, width: 500, height: 500)
    let segments = DockGeometry.exposedSegments(of: monitor, among: [monitor, a, b], edge: .bottom)
    #expect(segments == [0...100, 600...1000, 1500...2560])
}

@Test func sideEdgesUseVerticalSegments() {
    let side = CGRect(x: 2560, y: 400, width: 1000, height: 500)
    let segments = DockGeometry.exposedSegments(of: monitor, among: [monitor, side], edge: .right)
    #expect(segments == [0...400, 900...1440])
}

@Test func targetMonitorOnlyBlocksTheLaptopBottom() {
    let zones = DockGeometry.blockZones(target: monitor, displays: [monitor, laptop], edge: .bottom)
    #expect(zones == [BlockZone(rect: CGRect(x: 539, y: 2419, width: 1512, height: 3), edge: .bottom)])
}

@Test func cursorIsHeldAboveTheBlockedEdge() {
    let zones = DockGeometry.blockZones(target: monitor, displays: [monitor, laptop], edge: .bottom)
    #expect(DockGeometry.clamped(CGPoint(x: 1000, y: 2421), zones: zones) == CGPoint(x: 1000, y: 2418))
    #expect(DockGeometry.clamped(CGPoint(x: 1000, y: 2418), zones: zones) == nil)
}

@Test func crossingBetweenStackedDisplaysStaysAllowed() {
    let zones = DockGeometry.blockZones(target: laptop, displays: [monitor, laptop], edge: .bottom)
    // Monitor's exposed corners are blocked, the part above the laptop is not.
    #expect(DockGeometry.clamped(CGPoint(x: 1200, y: 1439), zones: zones) == nil)
    #expect(DockGeometry.clamped(CGPoint(x: 100, y: 1439), zones: zones) == CGPoint(x: 100, y: 1436))
}

@Test func pushPointUsesTheLongestExposedSegment() {
    let push = DockGeometry.pushPoint(target: monitor, displays: [monitor, laptop], edge: .bottom)
    #expect(push == PushPoint(point: CGPoint(x: 269.5, y: 1439), isExposed: true))
}

@Test func pushPointFlagsACoveredEdge() {
    let below = CGRect(x: 0, y: 1440, width: 2560, height: 1440)
    let push = DockGeometry.pushPoint(target: monitor, displays: [monitor, below], edge: .bottom)
    #expect(push == PushPoint(point: CGPoint(x: 1280, y: 1439), isExposed: false))
}
