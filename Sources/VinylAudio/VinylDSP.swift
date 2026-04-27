import Foundation

struct DSPParameters: Equatable {
    var surfaceNoise: Float = 0.30
    var crackleAmount: Float = 0.20
    var popAmount: Float = 0.10
    var warmth: Float = 0.40
    var wowFlutter: Float = 0.15
    var rumble: Float = 0.15
    var masterVolume: Float = 0.50
    var eqHigh: Float = 0.50
    var eqMid: Float = 0.50
    var eqLow: Float = 0.50
    var reverb: Float = 0.0
    var filterCutoff: Float = 1.0
    var filterResonance: Float = 0.0
    var filterIsHighPass: Bool = false
}

final class VinylDSP {
    var parameters = DSPParameters()
    var sampleRate: Float = 44100

    private var rngState: UInt64

    // Pink noise (Voss-McCartney, 12 octave bands)
    private var pinkRows = [Float](repeating: 0, count: 12)
    private var pinkRunningSum: Float = 0
    private var pinkCounter: UInt32 = 0

    // Crackle / pop envelopes
    private var crackleEnv: Float = 0
    private var crackleDecay: Float = 0.95
    private var popEnv: Float = 0
    private var popDecay: Float = 0.90

    // Rumble oscillators
    private var rumblePhase1: Float = 0
    private var rumblePhase2: Float = 0

    // Groove revolution modulation (33 RPM ~ 0.55 Hz)
    private var groovePhase: Float = 0

    // Warmth low-pass filter state
    private var lpfStateL: Float = 0
    private var lpfStateR: Float = 0

    // Stereo decorrelation delay
    private var decorrelBuf = [Float](repeating: 0, count: 64)
    private var decorrelIdx: Int = 0

    // Peak metering
    var peakL: Float = 0
    var peakR: Float = 0

    // Wow & flutter delay line
    private let maxDelay = 1024
    private var delayL: UnsafeMutablePointer<Float>
    private var delayR: UnsafeMutablePointer<Float>
    private var delayPos: Int = 0
    private var wowPhase: Float = 0
    private var flutterPhase: Float = 0

    // 3-band EQ state (L/R)
    private var eqLowL: Float = 0, eqLowR: Float = 0
    private var eqMidLoL: Float = 0, eqMidLoR: Float = 0
    private var eqMidHiL: Float = 0, eqMidHiR: Float = 0
    private var eqHighL: Float = 0, eqHighR: Float = 0

    // Resonant state variable filter (L/R)
    private var svfStateL1: Float = 0, svfStateL2: Float = 0
    private var svfStateR1: Float = 0, svfStateR2: Float = 0

    // Multi-tap delay reverb
    private static let reverbSize = 8192
    private let reverbTaps: [Int] = [1117, 1931, 2903, 3947, 5101, 6271, 7411]
    private var reverbBufL: UnsafeMutablePointer<Float>
    private var reverbBufR: UnsafeMutablePointer<Float>
    private var reverbPos: Int = 0
    private var reverbLPL: Float = 0
    private var reverbLPR: Float = 0

    init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        rngState = UInt64(truncating: NSNumber(
            value: CFAbsoluteTimeGetCurrent() * 1000
        )) ^ 0x853C49E6748FEA9B

        for i in 0..<pinkRows.count {
            let val = Float.random(in: -0.5...0.5)
            pinkRows[i] = val
            pinkRunningSum += val
        }

        delayL = .allocate(capacity: maxDelay)
        delayL.initialize(repeating: 0, count: maxDelay)
        delayR = .allocate(capacity: maxDelay)
        delayR.initialize(repeating: 0, count: maxDelay)

        reverbBufL = .allocate(capacity: Self.reverbSize)
        reverbBufL.initialize(repeating: 0, count: Self.reverbSize)
        reverbBufR = .allocate(capacity: Self.reverbSize)
        reverbBufR.initialize(repeating: 0, count: Self.reverbSize)
    }

    deinit {
        delayL.deinitialize(count: maxDelay)
        delayL.deallocate()
        delayR.deinitialize(count: maxDelay)
        delayR.deallocate()
        reverbBufL.deinitialize(count: Self.reverbSize)
        reverbBufL.deallocate()
        reverbBufR.deinitialize(count: Self.reverbSize)
        reverbBufR.deallocate()
    }

    // MARK: - Overlay Mode

    func render(
        frameCount: Int,
        leftBuffer: UnsafeMutablePointer<Float>,
        rightBuffer: UnsafeMutablePointer<Float>
    ) {
        let p = parameters
        var pL: Float = 0, pR: Float = 0

        for i in 0..<frameCount {
            var sample: Float = 0
            sample += nextPinkNoise() * p.surfaceNoise * p.surfaceNoise * 0.08
            sample += nextCrackle(p.crackleAmount) * 0.15
            sample += nextPop(p.popAmount) * 0.25
            sample += nextRumble() * p.rumble * 0.03
            sample *= 1.0 + nextGrooveModulation() * p.surfaceNoise * 0.12
            sample = softClip(sample, drive: p.warmth)
            sample *= p.masterVolume

            var (sL, sR) = stereoField(sample)

            let cutoff: Float = 1.0 - p.warmth * 0.35
            lpfStateL += cutoff * (sL - lpfStateL)
            lpfStateR += cutoff * (sR - lpfStateR)
            sL = lpfStateL; sR = lpfStateR

            sL = applyEQLChannel(sL, p)
            sR = applyEQRChannel(sR, p)
            applyFilter(&sL, &sR, p)
            applyReverb(&sL, &sR, p.reverb)

            leftBuffer[i] = sL
            rightBuffer[i] = sR
            pL = max(pL, abs(sL))
            pR = max(pR, abs(sR))
        }
        peakL = pL; peakR = pR
    }

    // MARK: - Passthrough Mode

    func processPassthrough(
        frameCount: Int,
        inputLeft: UnsafePointer<Float>,
        inputRight: UnsafePointer<Float>,
        outputLeft: UnsafeMutablePointer<Float>,
        outputRight: UnsafeMutablePointer<Float>
    ) {
        let p = parameters
        var pL: Float = 0, pR: Float = 0

        for i in 0..<frameCount {
            var sL = inputLeft[i]
            var sR = inputRight[i]

            sL = applyEQLChannel(sL, p)
            sR = applyEQRChannel(sR, p)
            applyFilter(&sL, &sR, p)

            if p.wowFlutter > 0.001 {
                (sL, sR) = applyWowFlutter(sL, sR, p.wowFlutter)
            }

            sL = softClip(sL, drive: p.warmth * 0.6)
            sR = softClip(sR, drive: p.warmth * 0.6)

            let cutoff: Float = 1.0 - p.warmth * 0.25
            lpfStateL += cutoff * (sL - lpfStateL)
            lpfStateR += cutoff * (sR - lpfStateR)
            sL = lpfStateL; sR = lpfStateR

            let noise = nextPinkNoise() * p.surfaceNoise * p.surfaceNoise * 0.05
            sL += noise + rnd() * 0.0005
            sR += noise + rnd() * 0.0005

            let crackle = nextCrackle(p.crackleAmount) * 0.10
            sL += crackle
            sR += crackle * (0.7 + rndPos() * 0.3)

            let pop = nextPop(p.popAmount) * 0.18
            sL += pop
            sR += pop * (0.8 + rndPos() * 0.2)

            let rum = nextRumble() * p.rumble * 0.015
            sL += rum; sR += rum

            let groove = nextGrooveModulation() * p.surfaceNoise * 0.04
            sL *= 1.0 + groove
            sR *= 1.0 + groove

            applyReverb(&sL, &sR, p.reverb)

            outputLeft[i] = sL
            outputRight[i] = sR
            pL = max(pL, abs(sL))
            pR = max(pR, abs(sR))
        }
        peakL = pL; peakR = pR
    }

    // MARK: - 3-Band EQ (additive shelves)

    private func applyEQLChannel(_ sample: Float, _ p: DSPParameters) -> Float {
        if p.eqHigh == 0.5 && p.eqMid == 0.5 && p.eqLow == 0.5 { return sample }
        let la: Float = 300 * 2 * .pi / sampleRate
        eqLowL += (la / (la + 1)) * (sample - eqLowL)
        let mla: Float = 500 * 2 * .pi / sampleRate
        eqMidLoL += (mla / (mla + 1)) * (sample - eqMidLoL)
        let mha: Float = 2000 * 2 * .pi / sampleRate
        eqMidHiL += (mha / (mha + 1)) * (sample - eqMidHiL)
        let ha: Float = 3000 * 2 * .pi / sampleRate
        eqHighL += (ha / (ha + 1)) * (sample - eqHighL)
        return sample
            + eqLowL * (eqGain(p.eqLow) - 1)
            + (eqMidHiL - eqMidLoL) * (eqGain(p.eqMid) - 1)
            + (sample - eqHighL) * (eqGain(p.eqHigh) - 1)
    }

    private func applyEQRChannel(_ sample: Float, _ p: DSPParameters) -> Float {
        if p.eqHigh == 0.5 && p.eqMid == 0.5 && p.eqLow == 0.5 { return sample }
        let la: Float = 300 * 2 * .pi / sampleRate
        eqLowR += (la / (la + 1)) * (sample - eqLowR)
        let mla: Float = 500 * 2 * .pi / sampleRate
        eqMidLoR += (mla / (mla + 1)) * (sample - eqMidLoR)
        let mha: Float = 2000 * 2 * .pi / sampleRate
        eqMidHiR += (mha / (mha + 1)) * (sample - eqMidHiR)
        let ha: Float = 3000 * 2 * .pi / sampleRate
        eqHighR += (ha / (ha + 1)) * (sample - eqHighR)
        return sample
            + eqLowR * (eqGain(p.eqLow) - 1)
            + (eqMidHiR - eqMidLoR) * (eqGain(p.eqMid) - 1)
            + (sample - eqHighR) * (eqGain(p.eqHigh) - 1)
    }

    private func eqGain(_ knob: Float) -> Float {
        knob <= 0.5 ? knob * 2 : 1 + (knob - 0.5) * 6
    }

    // MARK: - Resonant State Variable Filter

    private func applyFilter(_ sL: inout Float, _ sR: inout Float, _ p: DSPParameters) {
        if p.filterCutoff > 0.999 && !p.filterIsHighPass { return }
        if p.filterCutoff < 0.001 && p.filterIsHighPass { return }

        let freq = 20.0 * pow(Float(1000), p.filterCutoff)
        let f = 2.0 * sin(.pi * min(freq, sampleRate * 0.49) / sampleRate)
        let q = max(0.5, 1.0 - p.filterResonance * 0.9)

        let hpL = sL - svfStateL2 - svfStateL1 * q
        let bpL = hpL * f + svfStateL1; svfStateL1 = bpL
        let lpL = bpL * f + svfStateL2; svfStateL2 = lpL
        sL = p.filterIsHighPass ? hpL : lpL

        let hpR = sR - svfStateR2 - svfStateR1 * q
        let bpR = hpR * f + svfStateR1; svfStateR1 = bpR
        let lpR = bpR * f + svfStateR2; svfStateR2 = lpR
        sR = p.filterIsHighPass ? hpR : lpR
    }

    // MARK: - Multi-tap Reverb

    private func applyReverb(_ sL: inout Float, _ sR: inout Float, _ amount: Float) {
        guard amount > 0.001 else { return }

        let pos = reverbPos
        reverbBufL[pos] = sL + reverbLPL * amount * 0.55
        reverbBufR[pos] = sR + reverbLPR * amount * 0.55

        var wetL: Float = 0, wetR: Float = 0
        for tap in reverbTaps {
            let idx = ((pos - tap) % Self.reverbSize + Self.reverbSize) % Self.reverbSize
            wetL += reverbBufL[idx]
            wetR += reverbBufR[idx]
        }
        let invTaps = 1.0 / Float(reverbTaps.count)
        wetL *= invTaps; wetR *= invTaps

        reverbLPL = reverbLPL * 0.35 + wetL * 0.65
        reverbLPR = reverbLPR * 0.35 + wetR * 0.65

        reverbPos = (pos + 1) % Self.reverbSize

        let dry = 1.0 - amount * 0.3
        sL = sL * dry + wetL * amount
        sR = sR * dry + wetR * amount
    }

    // MARK: - Wow & Flutter

    private func applyWowFlutter(
        _ l: Float, _ r: Float, _ amount: Float
    ) -> (Float, Float) {
        delayL[delayPos] = l
        delayR[delayPos] = r

        wowPhase += 0.8 / sampleRate
        if wowPhase > 1.0 { wowPhase -= 1.0 }
        flutterPhase += 7.0 / sampleRate
        if flutterPhase > 1.0 { flutterPhase -= 1.0 }

        let wowDepth = amount * 0.003 * sampleRate
        let flutterDepth = amount * 0.0005 * sampleRate
        let modulation = sin(wowPhase * .pi * 2) * wowDepth
                       + sin(flutterPhase * .pi * 2) * flutterDepth
        let totalDelay = max(1.0, 10.0 + modulation)

        let readF = Float(delayPos) - totalDelay
        let readAdj = readF < 0 ? readF + Float(maxDelay) : readF
        let idx0 = Int(readAdj) % maxDelay
        let idx1 = (idx0 + 1) % maxDelay
        let frac = readAdj - floor(readAdj)

        let outL = delayL[idx0] * (1 - frac) + delayL[idx1] * frac
        let outR = delayR[idx0] * (1 - frac) + delayR[idx1] * frac

        delayPos = (delayPos + 1) % maxDelay
        return (outL, outR)
    }

    // MARK: - Pink Noise (Voss-McCartney)

    private func nextPinkNoise() -> Float {
        pinkCounter &+= 1
        let changed = pinkCounter ^ (pinkCounter &- 1)
        for row in 0..<pinkRows.count {
            if changed & (1 << row) != 0 {
                pinkRunningSum -= pinkRows[row]
                let newVal = rnd() * 0.5
                pinkRows[row] = newVal
                pinkRunningSum += newVal
                break
            }
        }
        return (pinkRunningSum + rnd() * 0.5) / Float(pinkRows.count + 1)
    }

    // MARK: - Crackle

    private func nextCrackle(_ intensity: Float) -> Float {
        if rndPos() < intensity * intensity * 0.002 && crackleEnv < 0.01 {
            crackleEnv = (0.3 + rndPos() * 0.7) * intensity
            crackleDecay = 0.92 + rndPos() * 0.06
        }
        let out = crackleEnv * rnd()
        crackleEnv *= crackleDecay
        if crackleEnv < 0.001 { crackleEnv = 0 }
        return out
    }

    // MARK: - Pops

    private func nextPop(_ frequency: Float) -> Float {
        if rndPos() < frequency * frequency * 0.0001 && popEnv < 0.01 {
            popEnv = 0.6 + rndPos() * 0.4
            popDecay = 0.85 + rndPos() * 0.10
        }
        let impulse: Float = popEnv > 0.5
            ? (rndPos() > 0.5 ? 1.0 : -1.0) : rnd()
        let out = popEnv * impulse
        popEnv *= popDecay
        if popEnv < 0.001 { popEnv = 0 }
        return out
    }

    // MARK: - Rumble

    private func nextRumble() -> Float {
        rumblePhase1 += 23.0 / sampleRate
        if rumblePhase1 > 1.0 { rumblePhase1 -= 1.0 }
        rumblePhase2 += 31.0 / sampleRate
        if rumblePhase2 > 1.0 { rumblePhase2 -= 1.0 }
        return sin(rumblePhase1 * .pi * 2) + sin(rumblePhase2 * .pi * 2) * 0.7
    }

    // MARK: - Groove Modulation

    private func nextGrooveModulation() -> Float {
        groovePhase += 0.55 / sampleRate
        if groovePhase > 1.0 { groovePhase -= 1.0 }
        let a = groovePhase * .pi * 2
        return sin(a) + sin(a * 2) * 0.3 + sin(a * 3) * 0.1
    }

    // MARK: - Saturation

    private func softClip(_ sample: Float, drive: Float) -> Float {
        tanh(sample * (1.0 + drive * 3.0)) * 0.7
    }

    // MARK: - Stereo Field

    private func stereoField(_ mono: Float) -> (Float, Float) {
        decorrelBuf[decorrelIdx] = mono
        let off = (decorrelIdx + decorrelBuf.count - 7) % decorrelBuf.count
        let delayed = decorrelBuf[off]
        decorrelIdx = (decorrelIdx + 1) % decorrelBuf.count
        return (mono * 0.7 + delayed * 0.3 + rnd() * 0.002,
                delayed * 0.7 + mono * 0.3 + rnd() * 0.002)
    }

    // MARK: - RNG (xorshift64)

    private func rnd() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 7
        rngState ^= rngState << 17
        return Float(rngState & 0xFF_FFFF) / Float(0xFF_FFFF) * 2.0 - 1.0
    }

    private func rndPos() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 7
        rngState ^= rngState << 17
        return Float(rngState & 0xFF_FFFF) / Float(0xFF_FFFF)
    }
}
