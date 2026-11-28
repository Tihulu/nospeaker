import Foundation
import Testing
@testable import NoSpeakerCore

@Test(arguments: [0.0, -120, Double.nan, .infinity, -.infinity, .leastNonzeroMagnitude])
func sequencerHapticsRejectInvalidTempo(bpm: Double) throws {
    let notes = NoteSequence(bpm: bpm, steps: [.init(index: 0, midi: 60), .init(index: 1, midi: 64)])
    let drums = DrumSequence(bpm: bpm, hits: [.init(index: 0, voice: .kick), .init(index: 1, voice: .snare)])
    #expect(try HapticPatternRenderer.notes(notes).isEmpty)
    #expect(HapticPatternRenderer.drums(drums).isEmpty)
}

@Test(arguments: [0, -1, Int.min])
func sequencerHapticsRejectInvalidSubdivision(subdivision: Int) throws {
    #expect(try HapticPatternRenderer.notes(.init(stepsPerBeat: subdivision, steps: [.init(index: 0, midi: 60)])).isEmpty)
    #expect(HapticPatternRenderer.drums(.init(stepsPerBeat: subdivision, hits: [.init(index: 0, voice: .kick)])).isEmpty)
}

@Test(arguments: [Double.nan, .infinity, -.infinity])
func sequencerHapticsSkipNonfiniteCells(value: Double) throws {
    let valid = NoteStep(index: 2, midi: 69, velocity: 0.5, gate: 0.5)
    let notes = NoteSequence(steps: [.init(index: 0, midi: 60, velocity: value), .init(index: 1, midi: 64, gate: value), valid])
    #expect(try HapticPatternRenderer.notes(notes) == HapticPatternRenderer.notes(.init(steps: [valid])))
    let hit = DrumStep(index: 2, voice: .snare, velocity: 0.5)
    #expect(HapticPatternRenderer.drums(.init(hits: [.init(index: 0, voice: .kick, velocity: value), hit])) == HapticPatternRenderer.drums(.init(hits: [hit])))
}

@Test func sequencerHapticsRejectOverflowedDerivedTiming() throws {
    let bpm = 1e-306
    let notes = NoteSequence(bpm: bpm, stepsPerBeat: 1, length: 100, steps: [.init(index: 0, midi: 60), .init(index: 99, midi: 64)])
    #expect(try HapticPatternRenderer.notes(notes).isEmpty)
    let drums = DrumSequence(bpm: bpm, stepsPerBeat: 1, length: 100, hits: [.init(index: 0, voice: .kick), .init(index: 99, voice: .snare)])
    let events = HapticPatternRenderer.drums(drums)
    #expect(events.count == 1)
    #expect(events.first?.time == 0)
}

@Test func sequencerHapticsPreserveValidTimingAndFiniteClamping() throws {
    let notes = NoteSequence(steps: [.init(index: 2, midi: 69, velocity: 2, gate: 2), .init(index: 1, midi: 69, velocity: -1, gate: 0)])
    let events = try HapticPatternRenderer.notes(notes)
    #expect(events.map(\.time) == [0.125, 0.25])
    #expect(events.map(\.frame.durationMS) == [6.25, 125])
    #expect(events.map(\.frame.level) == [0, 1])
    #expect(events.allSatisfy { $0.frame.tones == [.init(frequencyHz: 440)] })
    let drums = HapticPatternRenderer.drums(.init(hits: [.init(index: 2, voice: .kick, velocity: 2), .init(index: 1, voice: .snare, velocity: -1)]))
    #expect(drums.map(\.time) == [0.125, 0.25])
    #expect(drums.map(\.frame.level) == [0, 1])
    #expect(throws: MusicTheoryError.midiOutOfRange(128)) { try HapticPatternRenderer.notes(.init(steps: [.init(index: 0, midi: 128)])) }
}
