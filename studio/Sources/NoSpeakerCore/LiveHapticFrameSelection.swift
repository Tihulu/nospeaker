/// An attack snapshot is a best-effort transient, not a replacement for
/// current held notes. Keep every current tone and use spare actuator slots
/// for distinct recent pitches. The physical motor still has six voices.
public enum LiveHapticFrameSelection {
    public static func select(held: HapticFrame?, attack: HapticFrame?) -> HapticFrame? {
        // Admit each source independently so a malformed or silent frame
        // cannot escape validation or suppress an otherwise valid source.
        guard let held, valid(held) else {
            return attack.flatMap { valid($0) ? $0 : nil }
        }
        guard let attack, valid(attack) else { return held }
        let safety = HapticSafetyPolicy()
        guard held.tones.count < safety.maxTonesPerFrame else { return held }
        var frequencies = Set(held.tones.map(\.frequencyHz))
        var extras: [HapticTone] = []
        for tone in attack.tones where tone.amplitude > 0 {
            guard held.tones.count + extras.count < safety.maxTonesPerFrame else { break }
            if frequencies.insert(tone.frequencyHz).inserted { extras.append(tone) }
        }
        guard !extras.isEmpty else { return held }
        let heldSum = held.tones.reduce(0.0) { $0 + $1.amplitude }
        let attackSum = attack.tones.reduce(0.0) { $0 + $1.amplitude }
        guard heldSum > 0, attackSum > 0 else { return held }
        let tones = held.tones.map {
            HapticTone(frequencyHz:$0.frequencyHz,amplitude:$0.amplitude/heldSum*held.level)
        } + extras.map {
            HapticTone(frequencyHz:$0.frequencyHz,amplitude:$0.amplitude/attackSum*attack.level)
        }
        // Never extend a transient or boost level above the louder input.
        // The driver normalizes amplitudes; extra voices may share energy.
        return safety.clamp(.init(tones:tones,durationMS:min(held.durationMS,attack.durationMS),
                                  level:max(held.level,attack.level)))
    }

    private static func valid(_ frame: HapticFrame) -> Bool {
        frame.level.isFinite && frame.level > 0 && frame.level <= 1 &&
        frame.durationMS.isFinite && (0.5...120).contains(frame.durationMS) &&
        (1...6).contains(frame.tones.count) &&
        frame.tones.contains { $0.amplitude > 0 } &&
        frame.tones.allSatisfy {
            $0.frequencyHz.isFinite && (98...3951).contains($0.frequencyHz) &&
            $0.amplitude.isFinite && (0...1).contains($0.amplitude)
        }
    }
}
