import Testing
@testable import NoSpeakerCore

private func admissionFrame(_ hz: Double = 440) -> HapticFrame {
    .init(tones: [.init(frequencyHz: hz)], durationMS: 18, level: 0.5)
}

private func rejectedFrame(_ index: Int) -> HapticFrame {
    var frame = admissionFrame()
    switch index {
    case 0: frame.level = .nan
    case 1: frame.level = 0
    case 2: frame.level = 1.1
    case 3: frame.durationMS = .infinity
    case 4: frame.durationMS = 0.49
    case 5: frame.durationMS = 121
    case 6: frame.tones = []
    case 7: frame.tones = Array(repeating: .init(frequencyHz: 440), count: 7)
    case 8: frame.tones[0].frequencyHz = .nan
    case 9: frame.tones[0].frequencyHz = 97
    case 10: frame.tones[0].frequencyHz = 3952
    case 11: frame.tones[0].amplitude = .infinity
    case 12: frame.tones[0].amplitude = -0.1
    case 13: frame.tones[0].amplitude = 1.1
    default: frame.tones[0].amplitude = 0
    }
    return frame
}

@Test(arguments: Array(0..<15))
func liveHapticInvalidOrSilentSourceCannotEscapeOrMaskValidSource(index: Int) {
    let invalid = rejectedFrame(index)
    let valid = admissionFrame(660)
    #expect(LiveHapticFrameSelection.select(held: nil, attack: invalid) == nil)
    #expect(LiveHapticFrameSelection.select(held: invalid, attack: nil) == nil)
    #expect(LiveHapticFrameSelection.select(held: invalid, attack: invalid) == nil)
    #expect(LiveHapticFrameSelection.select(held: invalid, attack: valid) == valid)
    #expect(LiveHapticFrameSelection.select(held: valid, attack: invalid) == valid)
}

@Test func liveHapticValidBoundaryFramesRemainUnchangedWhenAlone() {
    let low = HapticFrame(tones: [.init(frequencyHz: 98, amplitude: 0.25)], durationMS: 0.5, level: 0.01)
    let high = HapticFrame(tones: [.init(frequencyHz: 3951)], durationMS: 120, level: 1)
    for frame in [low, high] {
        #expect(LiveHapticFrameSelection.select(held: frame, attack: nil) == frame)
        #expect(LiveHapticFrameSelection.select(held: nil, attack: frame) == frame)
    }
}
