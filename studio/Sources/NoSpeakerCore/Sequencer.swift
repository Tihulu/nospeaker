import Foundation

public struct NoteStep: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var index: Int
    public var midi: Int?
    public var velocity: Double
    public var gate: Double

    public init(id: UUID = UUID(), index: Int, midi: Int? = nil, velocity: Double = 0.85, gate: Double = 0.8) {
        self.id = id
        self.index = index
        self.midi = midi
        self.velocity = velocity
        self.gate = gate
    }
}

public enum DrumVoice: String, CaseIterable, Sendable, Codable, Hashable {
    case kick, snare, closedHat, openHat, clap, tom
}

public struct DrumStep: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var index: Int
    public var voice: DrumVoice
    public var velocity: Double

    public init(id: UUID = UUID(), index: Int, voice: DrumVoice, velocity: Double = 0.9) {
        self.id = id
        self.index = index
        self.voice = voice
        self.velocity = velocity
    }
}

public struct NoteSequence: Sendable, Equatable {
    public var bpm: Double
    public var stepsPerBeat: Int
    public var length: Int
    public var steps: [NoteStep]

    public init(bpm: Double = 120, stepsPerBeat: Int = 4, length: Int = 16, steps: [NoteStep] = []) {
        self.bpm = bpm
        self.stepsPerBeat = stepsPerBeat
        self.length = length
        self.steps = steps
    }

    public var stepDuration: Double { 60.0 / bpm / Double(stepsPerBeat) }
}

public struct DrumSequence: Sendable, Equatable {
    public var bpm: Double
    public var stepsPerBeat: Int
    public var length: Int
    public var hits: [DrumStep]

    public init(bpm: Double = 120, stepsPerBeat: Int = 4, length: Int = 16, hits: [DrumStep] = []) {
        self.bpm = bpm
        self.stepsPerBeat = stepsPerBeat
        self.length = length
        self.hits = hits
    }

    public var stepDuration: Double { 60.0 / bpm / Double(stepsPerBeat) }
}

public enum HapticPatternRenderer {
    public static func notes(_ sequence: NoteSequence) throws -> [ScheduledHapticEvent] {
        let stepDuration = sequence.stepDuration
        guard sequence.bpm.isFinite, sequence.bpm > 0, sequence.stepsPerBeat > 0,
              stepDuration.isFinite, stepDuration > 0 else { return [] }
        return try sequence.steps.compactMap { step in
            guard let midi = step.midi, step.index >= 0, step.index < sequence.length,
                  step.gate.isFinite, step.velocity.isFinite else { return nil }
            let time = Double(step.index) * stepDuration
            let durationMS = stepDuration * min(max(step.gate, 0.05), 1.0) * 1_000
            guard time.isFinite, durationMS.isFinite, durationMS > 0 else { return nil }
            let frequency = try MusicTheory.frequency(midi: midi)
            return ScheduledHapticEvent(
                time: time,
                frame: HapticFrame(
                    tones: [HapticTone(frequencyHz: frequency)],
                    durationMS: durationMS,
                    level: min(max(step.velocity, 0), 1)
                )
            )
        }.sorted { $0.time < $1.time }
    }

    public static func drums(_ sequence: DrumSequence) -> [ScheduledHapticEvent] {
        let stepDuration = sequence.stepDuration
        guard sequence.bpm.isFinite, sequence.bpm > 0, sequence.stepsPerBeat > 0,
              stepDuration.isFinite, stepDuration > 0 else { return [] }
        return sequence.hits.compactMap { hit in
            guard hit.index >= 0, hit.index < sequence.length, hit.velocity.isFinite else { return nil }
            let time = Double(hit.index) * stepDuration
            guard time.isFinite else { return nil }
            return ScheduledHapticEvent(
                time: time,
                frame: drumFrame(hit.voice, velocity: hit.velocity)
            )
        }.sorted { $0.time < $1.time }
    }

    /// Touch pads reuse the sequencer's six established voices. Additional
    /// GM pads have distinct, conservative haptic profiles rather than
    /// treating a percussion note number as an equal-tempered pitch.
    public static func drumFrame(midiNote: Int, velocity: Double) -> HapticFrame? {
        guard velocity.isFinite else { return nil }
        let level = min(max(velocity, 0), 1)
        switch midiNote {
        case 36: return drumFrame(.kick, velocity: level)
        case 38: return drumFrame(.snare, velocity: level)
        case 42: return drumFrame(.closedHat, velocity: level)
        case 46: return drumFrame(.openHat, velocity: level)
        case 39: return drumFrame(.clap, velocity: level)
        case 47: return drumFrame(.tom, velocity: level)
        case 37: return .init(tones: [.init(frequencyHz: 1100), .init(frequencyHz: 2400, amplitude: 0.4)], durationMS: 15, level: level)
        case 45: return .init(tones: [.init(frequencyHz: 165)], durationMS: 90, level: level)
        case 50: return .init(tones: [.init(frequencyHz: 320)], durationMS: 65, level: level)
        case 49: return .init(tones: [.init(frequencyHz: 2800), .init(frequencyHz: 3900, amplitude: 0.7)], durationMS: 105, level: level * 0.75)
        case 51: return .init(tones: [.init(frequencyHz: 2100), .init(frequencyHz: 3400, amplitude: 0.5)], durationMS: 90, level: level * 0.7)
        case 56: return .init(tones: [.init(frequencyHz: 560), .init(frequencyHz: 845, amplitude: 0.8)], durationMS: 55, level: level)
        case 35: return .init(tones: [.init(frequencyHz: 100), .init(frequencyHz: 180, amplitude: 0.35)], durationMS: 85, level: level)
        case 40: return .init(tones: [.init(frequencyHz: 500, amplitude: 0.4), .init(frequencyHz: 2200)], durationMS: 50, level: level)
        case 44: return .init(tones: [.init(frequencyHz: 3100)], durationMS: 24, level: level * 0.7)
        case 54: return .init(tones: [.init(frequencyHz: 1750, amplitude: 0.5), .init(frequencyHz: 3600)], durationMS: 45, level: level * 0.75)
        default:
            guard let voice = MIDIDrumMap.voice(for: midiNote) else { return nil }
            return drumFrame(voice, velocity: level)
        }
    }

    public static func drumFrame(_ voice: DrumVoice, velocity: Double) -> HapticFrame {
        // The nonoptional legacy API returns a silent frame for invalid input.
        let level = velocity.isFinite ? min(max(velocity, 0), 1) : 0
        switch voice {
        case .kick:
            return HapticFrame(tones: [HapticTone(frequencyHz: 120)], durationMS: 70, level: level)
        case .snare:
            return HapticFrame(
                tones: [HapticTone(frequencyHz: 1_700, amplitude: 0.6), HapticTone(frequencyHz: 2_800, amplitude: 0.4)],
                durationMS: 42,
                level: level
            )
        case .closedHat:
            return HapticFrame(tones: [HapticTone(frequencyHz: 3_700)], durationMS: 18, level: level * 0.75)
        case .openHat:
            return HapticFrame(tones: [HapticTone(frequencyHz: 3_500)], durationMS: 65, level: level * 0.75)
        case .clap:
            return HapticFrame(
                tones: [HapticTone(frequencyHz: 1_900), HapticTone(frequencyHz: 3_100)],
                durationMS: 32,
                level: level * 0.8
            )
        case .tom:
            return HapticFrame(tones: [HapticTone(frequencyHz: 220)], durationMS: 80, level: level)
        }
    }
}

public enum MIDIDrumMap {
    public static func voice(for note: Int) -> DrumVoice? {
        switch note {
        case 35, 36: return .kick
        case 38, 40: return .snare
        case 42, 44: return .closedHat
        case 46: return .openHat
        case 39: return .clap
        case 41, 43, 45, 47, 48, 50: return .tom
        default: return nil
        }
    }
}
