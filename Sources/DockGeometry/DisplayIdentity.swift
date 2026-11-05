/// What identifies a display across reconnects. macOS can give the same monitor a new UUID,
/// for example after it moves to another port, so the hardware numbers serve as a fallback.
public struct DisplayIdentity: Equatable, Sendable {
    public let uuid: String
    public let vendor: UInt32
    public let model: UInt32
    public let serial: UInt32

    public init(uuid: String, vendor: UInt32, model: UInt32, serial: UInt32) {
        self.uuid = uuid
        self.vendor = vendor
        self.model = model
        self.serial = serial
    }

    /// The connected display that is `self`, or nil if none can be told apart with certainty.
    public func match(among connected: [DisplayIdentity]) -> DisplayIdentity? {
        if let exact = connected.first(where: { $0.uuid == uuid }) {
            return exact
        }
        // Settings saved before the hardware numbers were stored have nothing to compare.
        guard vendor != 0 || model != 0 else { return nil }

        let sameHardware = connected.filter {
            $0.vendor == vendor && $0.model == model && $0.serial == serial
        }
        return sameHardware.count == 1 ? sameHardware[0] : nil
    }
}
