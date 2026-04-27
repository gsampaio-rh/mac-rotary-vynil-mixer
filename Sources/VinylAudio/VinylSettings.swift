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

    private var applyingPreset = false

    var dspParameters: DSPParameters {
        DSPParameters(
            surfaceNoise: surfaceNoise,
            crackleAmount: crackleAmount,
            popAmount: popAmount,
            warmth: warmth,
            wowFlutter: wowFlutter,
            rumble: rumble,
            masterVolume: masterVolume
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
        case .wellLoved:
            surfaceNoise = 0.30; crackleAmount = 0.20; popAmount = 0.10
            warmth = 0.40; wowFlutter = 0.15; rumble = 0.15
        case .vintage:
            surfaceNoise = 0.55; crackleAmount = 0.40; popAmount = 0.25
            warmth = 0.65; wowFlutter = 0.30; rumble = 0.30
        case .fleaMarket:
            surfaceNoise = 0.80; crackleAmount = 0.65; popAmount = 0.50
            warmth = 0.85; wowFlutter = 0.50; rumble = 0.45
        }
    }
}
