import Foundation
import Testing
@testable import NoSpeakerCore

@Test(arguments: Array(0...127), [Double.nan, .infinity, -.infinity])
func directGMDrumFrameRejectsNonfiniteVelocity(pitch: Int, velocity: Double) {
    #expect(HapticPatternRenderer.drumFrame(midiNote: pitch, velocity: velocity) == nil)
}

@Test(arguments: DrumVoice.allCases, [Double.nan, .infinity, -.infinity])
func directNamedDrumFrameSilencesNonfiniteVelocity(voice: DrumVoice, velocity: Double) {
    let frame = HapticPatternRenderer.drumFrame(voice, velocity: velocity)
    #expect(frame == HapticPatternRenderer.drumFrame(voice, velocity: 0))
    #expect(frame.level == 0)
}

@Test(arguments: Array(0...127))
func directGMDrumFrameRetainsFiniteClampingAndSupportedVoices(pitch: Int) {
    let supported: Set<Int> = [35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,54,56]
    let zero = HapticPatternRenderer.drumFrame(midiNote: pitch, velocity: 0)
    let full = HapticPatternRenderer.drumFrame(midiNote: pitch, velocity: 1)
    let middle = HapticPatternRenderer.drumFrame(midiNote: pitch, velocity: 0.5)
    #expect((full != nil) == supported.contains(pitch))
    #expect(HapticPatternRenderer.drumFrame(midiNote: pitch, velocity: -1) == zero)
    #expect(HapticPatternRenderer.drumFrame(midiNote: pitch, velocity: 2) == full)
    if let zero, let full, let middle {
        #expect(zero.level == 0)
        #expect(middle.level == full.level * 0.5)
        #expect(zero.tones == full.tones && middle.tones == full.tones)
        #expect(zero.durationMS == full.durationMS && middle.durationMS == full.durationMS)
    }
}

@Test(arguments: DrumVoice.allCases)
func directNamedDrumFrameRetainsFiniteClamping(voice: DrumVoice) {
    let zero = HapticPatternRenderer.drumFrame(voice, velocity: 0)
    let full = HapticPatternRenderer.drumFrame(voice, velocity: 1)
    #expect(HapticPatternRenderer.drumFrame(voice, velocity: -1) == zero)
    #expect(HapticPatternRenderer.drumFrame(voice, velocity: 2) == full)
    #expect(HapticPatternRenderer.drumFrame(voice, velocity: 0.5).level == full.level * 0.5)
}
