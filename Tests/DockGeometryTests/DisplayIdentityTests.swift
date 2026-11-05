import Testing
@testable import DockGeometry

private let monitor = DisplayIdentity(uuid: "A", vendor: 1, model: 2, serial: 3)
private let laptop = DisplayIdentity(uuid: "L", vendor: 9, model: 9, serial: 9)

@Test func sameUUIDMatches() {
    #expect(monitor.match(among: [laptop, monitor]) == monitor)
}

@Test func monitorWithANewUUIDIsStillRecognised() {
    let reconnected = DisplayIdentity(uuid: "B", vendor: 1, model: 2, serial: 3)
    #expect(monitor.match(among: [laptop, reconnected]) == reconnected)
}

@Test func differentSerialIsADifferentMonitor() {
    let other = DisplayIdentity(uuid: "B", vendor: 1, model: 2, serial: 4)
    #expect(monitor.match(among: [laptop, other]) == nil)
}

@Test func identicalMonitorsWithoutSerialsAreNotGuessed() {
    let saved = DisplayIdentity(uuid: "A", vendor: 1, model: 2, serial: 0)
    let first = DisplayIdentity(uuid: "B", vendor: 1, model: 2, serial: 0)
    let second = DisplayIdentity(uuid: "C", vendor: 1, model: 2, serial: 0)
    #expect(saved.match(among: [first, second]) == nil)
    #expect(saved.match(among: [laptop, first]) == first)
}

@Test func settingsWithoutHardwareNumbersOnlyMatchByUUID() {
    let legacy = DisplayIdentity(uuid: "A", vendor: 0, model: 0, serial: 0)
    let unknown = DisplayIdentity(uuid: "B", vendor: 0, model: 0, serial: 0)
    #expect(legacy.match(among: [unknown]) == nil)
    #expect(legacy.match(among: [monitor]) == monitor)
}
