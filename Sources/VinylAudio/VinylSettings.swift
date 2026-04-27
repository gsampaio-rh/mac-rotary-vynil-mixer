import Foundation
import SwiftUI

enum VinylPreset: String, CaseIterable, Identifiable {
    case pristine = "Pristine"
    case wellLoved = "Well-Loved"
    case vintage = "Vintage"
    case fleaMarket = "Flea Market"

    var id: String { rawValue }
}

final class VinylSettings: ObservableObject {
    @Published var selectedPreset: VinylPreset? = .wellLoved

    @Published var surfaceNoise: Float = 0.30 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var crackleAmount: Float = 0.20 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var popAmount: Float = 0.10 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var warmth: Float = 0.40 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var wowFlutter: Float = 0.15 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var rumble: Float = 0.15 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var masterVolume: Float = 0.50

    // EQ
    @Published var eqHigh: Float = 0.50 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var eqMid: Float = 0.50 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var eqLow: Float = 0.50 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }

    // Effects
    @Published var reverb: Float = 0.0 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var filterCutoff: Float = 1.0 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var filterResonance: Float = 0.0 {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }
    @Published var filterIsHighPass: Bool = false {
        didSet { if !applyingPreset { selectedPreset = nil } }
    }

    private var applyingPreset = false

    var dspParameters: DSPParameters {
        DSPParameters(
            surfaceNoise: surfaceNoise,
            crackleAmount: crackleAmount,
            popAmount: popAmount,
            warmth: warmth,
            wowFlutter: wowFlutter,
            rumble: rumble,
            masterVolume: masterVolume,
            eqHigh: eqHigh,
            eqMid: eqMid,
            eqLow: eqLow,
            reverb: reverb,
            filterCutoff: filterCutoff,
            filterResonance: filterResonance,
            filterIsHighPass: filterIsHighPass
        )
    }

    func applyPreset(_ preset: VinylPreset) {
        applyingPreset = true
        defer { applyingPreset = false }

        selectedPreset = preset
        switch preset {
        case .pristine:
            surfaceNoise = 0.10; crackleAmount = 0.05; popAmount = 0.02
            warmth = 0.20; wowFlutter = 0.05; rumble = 0.05
            eqHigh = 0.50; eqMid = 0.50; eqLow = 0.50
            reverb = 0.0; filterCutoff = 1.0; filterResonance = 0.0
        case .wellLoved:
            surfaceNoise = 0.30; crackleAmount = 0.20; popAmount = 0.10
            warmth = 0.40; wowFlutter = 0.15; rumble = 0.15
            eqHigh = 0.45; eqMid = 0.50; eqLow = 0.55
            reverb = 0.0; filterCutoff = 1.0; filterResonance = 0.0
        case .vintage:
            surfaceNoise = 0.55; crackleAmount = 0.40; popAmount = 0.25
            warmth = 0.65; wowFlutter = 0.30; rumble = 0.30
            eqHigh = 0.38; eqMid = 0.52; eqLow = 0.60
            reverb = 0.10; filterCutoff = 0.85; filterResonance = 0.0
        case .fleaMarket:
            surfaceNoise = 0.80; crackleAmount = 0.65; popAmount = 0.50
            warmth = 0.85; wowFlutter = 0.50; rumble = 0.45
            eqHigh = 0.30; eqMid = 0.55; eqLow = 0.65
            reverb = 0.15; filterCutoff = 0.70; filterResonance = 0.10
        }
        filterIsHighPass = false
    }
}
