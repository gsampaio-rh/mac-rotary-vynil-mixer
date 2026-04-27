import Foundation

struct DSPParameters: Equatable {
    var surfaceNoise: Float = 0.30
    var crackleAmount: Float = 0.20
    var popAmount: Float = 0.10
    var warmth: Float = 0.40
    var wowFlutter: Float = 0.15
    var rumble: Float = 0.15
    var masterVolume: Float = 0.50
}

final class VinylDSP {
    var parameters = DSPParameters()
    var sampleRate: Float = 44100

    // Xorshift64 RNG — real-time safe, no allocations
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

    // Groove revolution modulation (33 RPM ≈ 0.55 Hz)
    private var groovePhase: Float = 0

    // Warmth low-pass filter state
    private var lpfStateL: Float = 0
    private var lpfStateR: Float = 0

    // Stereo decorrelation delay
    private var decorrelBuf = [Float](repeating: 0, count: 64)
    private var decorrelIdx: Int = 0

    // Peak metering (read from main thread, written from audio thread)
    var peakL: Float = 0
    var peakR: Float = 0

    // Wow & flutter delay line (passthrough mode)
    private let maxDelay = 1024
    private var delayL: UnsafeMutablePointer<Float>
    private var delayR: UnsafeMutablePointer<Float>
    private var delayPos: Int = 0
    private var wowPhase: Float = 0
    private var flutterPhase: Float = 0

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
    }

    deinit {
        delayL.deinitialize(count: maxDelay)
        delayL.deallocate()
        delayR.deinitialize(count: maxDelay)
        delayR.deallocate()
    }

    // MARK: - Overlay Mode (noise-only output)

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

            let (left, right) = stereoField(sample)

            let cutoff: Float = 1.0 - p.warmth * 0.35
            lpfStateL += cutoff * (left - lpfStateL)
            lpfStateR += cutoff * (right - lpfStateR)

            leftBuffer[i] = lpfStateL
            rightBuffer[i] = lpfStateR
            pL = max(pL, abs(lpfStateL))
            pR = max(pR, abs(lpfStateR))
        }
        peakL = pL; peakR = pR
    }

    // MARK: - Passthrough Mode (process real audio signal)

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

            if p.wowFlutter > 0.001 {
                (sL, sR) = applyWowFlutter(sL, sR, p.wowFlutter)
            }

            // Analog warmth: saturation (lighter drive than overlay mode)
            sL = softClip(sL, drive: p.warmth * 0.6)
            sR = softClip(sR, drive: p.warmth * 0.6)

            // Warmth LPF (gentle high-frequency rolloff)
            let cutoff: Float = 1.0 - p.warmth * 0.25
            lpfStateL += cutoff * (sL - lpfStateL)
            lpfStateR += cutoff * (sR - lpfStateR)
            sL = lpfStateL
            sR = lpfStateR

            // Mix in surface noise
            let noise = nextPinkNoise() * p.surfaceNoise * p.surfaceNoise * 0.05
            sL += noise + rnd() * 0.0005
            sR += noise + rnd() * 0.0005

            // Crackle & pops (slightly different per channel for realism)
            let crackle = nextCrackle(p.crackleAmount) * 0.10
            sL += crackle
            sR += crackle * (0.7 + rndPos() * 0.3)

            let pop = nextPop(p.popAmount) * 0.18
            sL += pop
            sR += pop * (0.8 + rndPos() * 0.2)

            // Rumble
            let rum = nextRumble() * p.rumble * 0.015
            sL += rum
            sR += rum

            // Groove modulation
            let groove = nextGrooveModulation() * p.surfaceNoise * 0.04
            sL *= 1.0 + groove
            sR *= 1.0 + groove

            outputLeft[i] = sL
            outputRight[i] = sR
            pL = max(pL, abs(sL))
            pR = max(pR, abs(sR))
        }
        peakL = pL; peakR = pR
    }

    // MARK: - Wow & Flutter (variable delay line)

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
            ? (rndPos() > 0.5 ? 1.0 : -1.0)
            : rnd()
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

    // MARK: - Real-time safe RNG (xorshift64)

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
