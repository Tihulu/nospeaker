import Testing
@testable import NoSpeakerCore

private let expiryFrame = HapticFrame(tones: [.init(frequencyHz: 120)], durationMS: 20, level: 0.5)
private let expiryOrigins: [Double] = [0, 0.001, 0.1, 0.25, 0.5, 1, 2, 10, 60, 1000, 86400, 1_000_000]

@Test(arguments: expiryOrigins, [-1, 0, 1])
func attackExpiryUsesAbsoluteDeadline(origin: Double, offset: Int) {
    let deadline = origin + HapticAttackBuffer<Int>.maximumAge
    let now = offset < 0 ? deadline.nextDown : offset > 0 ? deadline.nextUp : deadline
    var attacks = HapticAttackBuffer<Int>()
    attacks.offer(7, now: origin)
    #expect(attacks.take(now: now) == (offset < 0 ? 7 : nil))
    #expect(attacks.isEmpty)
    var strikes = DrumHapticStrikeBuffer()
    strikes.receive(contacts: ["kick"], now: origin) { _ in expiryFrame }
    #expect(strikes.drain(now: now) == (offset < 0 ? [expiryFrame] : []))
    #expect(!strikes.hasPending)
}

@Test(arguments: expiryOrigins)
func expiryPruningOnNewInputDoesNotKeepExpiredAttacks(origin: Double) {
    let deadline = origin + HapticAttackBuffer<Int>.maximumAge
    var attacks = HapticAttackBuffer<Int>()
    attacks.offer(1, now: origin)
    attacks.offer(2, now: deadline)
    #expect(attacks.drain(now: deadline) == [2])
    var strikes = DrumHapticStrikeBuffer()
    strikes.receive(contacts: ["kick"], now: origin) { _ in expiryFrame }
    let other = HapticFrame(tones: [.init(frequencyHz: 200)], durationMS: 20, level: 0.5)
    strikes.receive(contacts: ["kick", "snare"], now: deadline) { _ in other }
    #expect(strikes.drain(now: deadline) == [other])
}

@Test func unresolvableClockPrecisionDoesNotExtendAttackLifetime() {
    let origin = 1e16
    #expect(origin + HapticAttackBuffer<Int>.maximumAge == origin)
    var attacks = HapticAttackBuffer<Int>()
    attacks.offer(1, now: origin)
    #expect(attacks.take(now: origin) == nil)
    var strikes = DrumHapticStrikeBuffer()
    strikes.receive(contacts: ["kick"], now: origin) { _ in expiryFrame }
    #expect(strikes.drain(now: origin).isEmpty)
}
