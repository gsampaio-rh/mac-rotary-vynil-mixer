import CoreAudio

struct AudioDeviceInfo: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let isInput: Bool
    let isOutput: Bool
}

enum DeviceManager {

    // MARK: - Device Enumeration

    static func allDevices() -> [AudioDeviceInfo] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: AudioObjectPropertyElement(0)
        )

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        ) == noErr else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids
        ) == noErr else { return [] }

        return ids.compactMap { id in
            guard let name = deviceName(id), let uid = deviceUID(id) else { return nil }
            return AudioDeviceInfo(
                id: id, name: name, uid: uid,
                isInput: hasStreams(id, scope: kAudioObjectPropertyScopeInput),
                isOutput: hasStreams(id, scope: kAudioObjectPropertyScopeOutput)
            )
        }
    }

    static func findBlackHole() -> AudioDeviceInfo? {
        allDevices().first {
            $0.name.localizedCaseInsensitiveContains("blackhole") && $0.isInput
        }
    }

    // MARK: - Default Device Management

    static func defaultOutputDevice() -> AudioDeviceID? {
        getDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    static func defaultInputDevice() -> AudioDeviceID? {
        getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
    }

    @discardableResult
    static func setDefaultOutputDevice(_ deviceID: AudioDeviceID) -> Bool {
        setDefaultDevice(deviceID, selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    @discardableResult
    static func setDefaultInputDevice(_ deviceID: AudioDeviceID) -> Bool {
        setDefaultDevice(deviceID, selector: kAudioHardwarePropertyDefaultInputDevice)
    }

    // MARK: - Crash Recovery

    private static let outputKey = "VinylAudio.originalOutputDeviceID"
    private static let inputKey = "VinylAudio.originalInputDeviceID"

    static func persistOriginalDevices(output: AudioDeviceID, input: AudioDeviceID?) {
        UserDefaults.standard.set(Int(output), forKey: outputKey)
        if let input { UserDefaults.standard.set(Int(input), forKey: inputKey) }
    }

    static func clearPersistedDevices() {
        UserDefaults.standard.removeObject(forKey: outputKey)
        UserDefaults.standard.removeObject(forKey: inputKey)
    }

    static func restorePersistedDevices() {
        guard let savedOutput = UserDefaults.standard.object(forKey: outputKey) as? Int else { return }

        if let current = defaultOutputDevice(),
           let name = deviceName(current),
           name.localizedCaseInsensitiveContains("blackhole") {
            setDefaultOutputDevice(AudioDeviceID(savedOutput))
        }

        if let savedInput = UserDefaults.standard.object(forKey: inputKey) as? Int,
           let current = defaultInputDevice(),
           let name = deviceName(current),
           name.localizedCaseInsensitiveContains("blackhole") {
            setDefaultInputDevice(AudioDeviceID(savedInput))
        }

        clearPersistedDevices()
    }

    // MARK: - Helpers

    private static func getDefaultDevice(selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: AudioObjectPropertyElement(0)
        )
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        ) == noErr else { return nil }
        return deviceID
    }

    private static func setDefaultDevice(
        _ deviceID: AudioDeviceID,
        selector: AudioObjectPropertySelector
    ) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: AudioObjectPropertyElement(0)
        )
        var id = deviceID
        return AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &id
        ) == noErr
    }

    static func deviceName(_ id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: AudioObjectPropertyElement(0)
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr,
              let cfName = name?.takeUnretainedValue() else {
            return nil
        }
        return cfName as String
    }

    private static func deviceUID(_ id: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: AudioObjectPropertyElement(0)
        )
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &uid) == noErr,
              let cfUID = uid?.takeUnretainedValue() else {
            return nil
        }
        return cfUID as String
    }

    private static func hasStreams(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: AudioObjectPropertyElement(0)
        )
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }
}
