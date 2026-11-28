/// One attack per down contact, including simultaneous fingers on distinct
/// pads. A lift rearms only that contact. Motor strikes are time-bounded,
/// separate from MIDI note ownership and release handling.
public struct DrumHapticStrikeBuffer: Sendable {
    private struct Strike: Sendable {
        let frame: HapticFrame
        let time: Double
    }
    private var down: Set<String> = []
    private var pending: [Strike] = []
    public static let capacity = 16
    public static let maximumAge = 0.040
    public init() {}
    public var hasPending: Bool { !pending.isEmpty }

    @discardableResult
    public mutating func receive(contacts: [String], now: Double,
                                 makeFrame: (String) -> HapticFrame?) -> Int {
        guard now.isFinite, now >= 0 else { return 0 }
        prune(now:now)
        var next: Set<String> = []
        var accepted = 0
        for id in contacts where next.insert(id).inserted {
            guard !down.contains(id), let frame = makeFrame(id) else { continue }
            if pending.count == Self.capacity { pending.removeFirst() }
            pending.append(.init(frame:frame,time:now))
            accepted += 1
        }
        down = next
        return accepted
    }

    private mutating func prune(now: Double) {
        // Compare absolute representable deadlines; subtraction can round
        // a nominal expiry down. A collapsed deadline expires immediately.
        pending.removeAll { now < $0.time || now >= $0.time + Self.maximumAge }
    }

    public mutating func drain(now: Double) -> [HapticFrame] {
        guard now.isFinite, now >= 0 else { pending.removeAll(); return [] }
        prune(now:now)
        let result = pending.map(\.frame)
        pending.removeAll(keepingCapacity:true)
        return result
    }

    /// Invalidate queued pulses without re-triggering still-held fingers.
    public mutating func discardPending() { pending.removeAll(keepingCapacity:true) }

    public mutating func reset() {
        down.removeAll(keepingCapacity:true)
        pending.removeAll(keepingCapacity:true)
    }
}
