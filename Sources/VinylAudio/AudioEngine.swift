import AppKit
import AVFoundation
import AudioToolbox

final class AudioEngineManager: ObservableObject {
    @Published var isOverlayActive = false
    @Published var isPassthroughActive = false
    @Published var blackHoleAvailable = false
    @Published var error: String?
    @Published var levelL: Float = 0
    @Published var levelR: Float = 0

    var isRunning: Bool { isOverlayActive || isPassthroughActive }

    private let overlayDSP = VinylDSP()
    private let passthroughDSP = VinylDSP()

    private var overlayEngine: AVAudioEngine?
    private var overlayNode: AVAudioSourceNode?

    private var captureEngine: AVAudioEngine?
    private var playbackEngine: AVAudioEngine?
    private var playbackNode: AVAudioSourceNode?
    private var originalOutputDeviceID: AudioDeviceID?
    private var originalInputDeviceID: AudioDeviceID?
    private var ringBufferL: AudioRingBuffer?
    private var ringBufferR: AudioRingBuffer?
    private var tempL: UnsafeMutablePointer<Float>?
    private var tempR: UnsafeMutablePointer<Float>?

    private static let maxFrames = 4096
    private var meterTimer: Timer?

    init() {
        blackHoleAvailable = DeviceManager.findBlackHole() != nil

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.stop()
        }
    }

    // MARK: - Public Controls

    func toggleOverlay(settings: VinylSettings) {
        if isOverlayActive {
            stopOverlay()
            isOverlayActive = false
            if !isPassthroughActive { stopMetering() }
        } else {
            startOverlay(settings: settings)
        }
    }

    func togglePassthrough(settings: VinylSettings) {
        if isPassthroughActive {
            stopPassthrough()
            isPassthroughActive = false
            if !isOverlayActive { stopMetering() }
        } else {
            requestMicAccess { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.doStartPassthrough(settings: settings)
                } else {
                    self.error = "Microphone access required — enable in System Settings → Privacy"
                }
            }
        }
    }

    func stop() {
        stopOverlay()
        stopPassthrough()
        stopMetering()
        isOverlayActive = false
        isPassthroughActive = false
    }

    func updateParameters(_ params: DSPParameters) {
        overlayDSP.parameters = params
        passthroughDSP.parameters = params
    }

    // MARK: - Microphone Permission

    private func requestMicAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    // MARK: - VU Metering

    private func startMetering() {
        guard meterTimer == nil else { return }
        meterTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            let oL = self.overlayDSP.peakL
            let oR = self.overlayDSP.peakR
            let pL = self.passthroughDSP.peakL
            let pR = self.passthroughDSP.peakR

            self.levelL = max(oL, pL)
            self.levelR = max(oR, pR)

            self.overlayDSP.peakL *= 0.82
            self.overlayDSP.peakR *= 0.82
            self.passthroughDSP.peakL *= 0.82
            self.passthroughDSP.peakR *= 0.82
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        levelL = 0
        levelR = 0
    }

    // MARK: - Overlay Mode

    private func startOverlay(settings: VinylSettings) {
        stopOverlay()

        let engine = AVAudioEngine()
        let hwRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = hwRate > 0 ? hwRate : 44100

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
            channels: 2, interleaved: false
        ) else {
            error = "Cannot create audio format"
            return
        }

        overlayDSP.sampleRate = Float(sampleRate)
        overlayDSP.parameters = settings.dspParameters

        let dsp = overlayDSP
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, abl in
            let bufs = UnsafeMutableAudioBufferListPointer(abl)
            guard bufs.count >= 2,
                  let ld = bufs[0].mData, let rd = bufs[1].mData else { return noErr }
            dsp.render(
                frameCount: Int(frameCount),
                leftBuffer: ld.assumingMemoryBound(to: Float.self),
                rightBuffer: rd.assumingMemoryBound(to: Float.self)
            )
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)

        // If passthrough is active, pin overlay to the real speakers (not BlackHole)
        if isPassthroughActive, let origOut = originalOutputDeviceID {
            engine.prepare()
            setDeviceOnUnit(engine.outputNode.audioUnit, deviceID: origOut)
        }

        do {
            try engine.start()
            self.overlayEngine = engine
            self.overlayNode = node
            isOverlayActive = true
            error = nil
            startMetering()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func stopOverlay() {
        overlayEngine?.stop()
        if let node = overlayNode { overlayEngine?.detach(node) }
        overlayEngine = nil
        overlayNode = nil
    }

    // MARK: - Passthrough Mode

    private func doStartPassthrough(settings: VinylSettings) {
        stopPassthrough()

        let blackHole = DeviceManager.findBlackHole()
        blackHoleAvailable = blackHole != nil
        guard let blackHole else {
            error = "BlackHole not found"
            return
        }

        // Resolve original output — skip if it's already BlackHole (crash recovery)
        var origOutput = DeviceManager.defaultOutputDevice()
        if let out = origOutput,
           DeviceManager.deviceName(out)?.localizedCaseInsensitiveContains("blackhole") == true {
            DeviceManager.restorePersistedDevices()
            origOutput = DeviceManager.defaultOutputDevice()
        }
        guard let origOutput,
              DeviceManager.deviceName(origOutput)?.localizedCaseInsensitiveContains("blackhole") != true else {
            error = "Cannot detect physical output device"
            return
        }
        let origInput = DeviceManager.defaultInputDevice()

        originalOutputDeviceID = origOutput
        originalInputDeviceID = origInput

        // Route system audio → BlackHole
        guard DeviceManager.setDefaultOutputDevice(blackHole.id) else {
            error = "Failed to route audio to BlackHole"
            return
        }
        DeviceManager.setDefaultInputDevice(blackHole.id)
        DeviceManager.persistOriginalDevices(output: origOutput, input: origInput)

        // Pin overlay engine to real speakers so it doesn't follow the default to BlackHole
        if isOverlayActive, let overlayEng = overlayEngine {
            setDeviceOnUnit(overlayEng.outputNode.audioUnit, deviceID: origOutput)
        }

        // --- Capture Engine: reads from BlackHole ---
        let capture = AVAudioEngine()

        // Explicitly set input device to BlackHole (don't rely solely on system default)
        setDeviceOnUnit(capture.inputNode.audioUnit, deviceID: blackHole.id)

        let inputFormat = capture.inputNode.inputFormat(forBus: 0)
        let sampleRate = inputFormat.sampleRate > 0 ? inputFormat.sampleRate : 48000
        let channels = inputFormat.channelCount

        let bufCap = Int(sampleRate)
        let ringL = AudioRingBuffer(capacity: bufCap)
        let ringR = AudioRingBuffer(capacity: bufCap)
        self.ringBufferL = ringL
        self.ringBufferR = ringR

        capture.connect(capture.inputNode, to: capture.mainMixerNode, format: inputFormat)
        capture.mainMixerNode.outputVolume = 0

        capture.inputNode.installTap(
            onBus: 0, bufferSize: 512, format: inputFormat
        ) { buffer, _ in
            guard let cd = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            ringL.write(cd[0], count: frames)
            ringR.write(channels >= 2 ? cd[1] : cd[0], count: frames)
        }

        do {
            try capture.start()
        } catch {
            restoreDevices()
            self.error = "Capture: \(error.localizedDescription)"
            return
        }
        self.captureEngine = capture

        // --- Playback Engine: outputs to original speakers ---
        let playback = AVAudioEngine()

        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
            channels: 2, interleaved: false
        ) else {
            stopPassthrough()
            error = "Cannot create audio format"
            return
        }

        passthroughDSP.sampleRate = Float(sampleRate)
        passthroughDSP.parameters = settings.dspParameters

        let tL = UnsafeMutablePointer<Float>.allocate(capacity: Self.maxFrames)
        tL.initialize(repeating: 0, count: Self.maxFrames)
        let tR = UnsafeMutablePointer<Float>.allocate(capacity: Self.maxFrames)
        tR.initialize(repeating: 0, count: Self.maxFrames)
        self.tempL = tL
        self.tempR = tR

        let dsp = passthroughDSP
        let node = AVAudioSourceNode(format: format) { _, _, frameCount, abl in
            let count = Int(frameCount)
            let bufs = UnsafeMutableAudioBufferListPointer(abl)
            guard bufs.count >= 2,
                  let ld = bufs[0].mData, let rd = bufs[1].mData else { return noErr }

            ringL.read(tL, count: count)
            ringR.read(tR, count: count)

            dsp.processPassthrough(
                frameCount: count,
                inputLeft: tL, inputRight: tR,
                outputLeft: ld.assumingMemoryBound(to: Float.self),
                outputRight: rd.assumingMemoryBound(to: Float.self)
            )
            return noErr
        }

        playback.attach(node)
        playback.connect(node, to: playback.mainMixerNode, format: format)

        // Set output to real speakers BEFORE starting to avoid any frames going to BlackHole
        playback.prepare()
        setDeviceOnUnit(playback.outputNode.audioUnit, deviceID: origOutput)

        do {
            try playback.start()
        } catch {
            stopPassthrough()
            self.error = "Playback: \(error.localizedDescription)"
            return
        }

        self.playbackEngine = playback
        self.playbackNode = node
        isPassthroughActive = true
        error = nil
        startMetering()
    }

    private func stopPassthrough() {
        captureEngine?.inputNode.removeTap(onBus: 0)
        captureEngine?.stop()
        captureEngine = nil

        playbackEngine?.stop()
        if let node = playbackNode { playbackEngine?.detach(node) }
        playbackEngine = nil
        playbackNode = nil

        restoreDevices()
        deallocPassthroughBuffers()
    }

    // MARK: - Device Routing

    private func setDeviceOnUnit(_ audioUnit: AudioUnit?, deviceID: AudioDeviceID) {
        guard let au = audioUnit else { return }
        var id = deviceID
        let status = AudioUnitSetProperty(
            au,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global, 0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            error = "Device redirect failed (\(status))"
        }
    }

    private func restoreDevices() {
        if let outID = originalOutputDeviceID {
            DeviceManager.setDefaultOutputDevice(outID)
            originalOutputDeviceID = nil
        }
        if let inID = originalInputDeviceID {
            DeviceManager.setDefaultInputDevice(inID)
            originalInputDeviceID = nil
        }
        DeviceManager.clearPersistedDevices()
    }

    private func deallocPassthroughBuffers() {
        tempL?.deinitialize(count: Self.maxFrames)
        tempL?.deallocate()
        tempR?.deinitialize(count: Self.maxFrames)
        tempR?.deallocate()
        tempL = nil
        tempR = nil
        ringBufferL = nil
        ringBufferR = nil
    }
}
