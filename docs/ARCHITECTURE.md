# Architecture: Mac Rotary Vynil Mixer

**Related:** [README](../README.md) | [Changelog](CHANGELOG.md)

## System Overview

Mac Rotary Vynil Mixer is a macOS menu bar application that simulates vinyl record audio characteristics in real time. The app has no external dependencies — it uses only Apple frameworks (SwiftUI, AVFoundation, CoreAudio, AudioToolbox).

```
┌─────────────────────────────────────────────────────────┐
│                    macOS Menu Bar                        │
│                  ┌──────────────┐                        │
│                  │ MenuBarExtra │                        │
│                  └──────┬───────┘                        │
│                         │                               │
│              ┌──────────▼──────────┐                    │
│              │    MenuBarView      │ ◄── VinylSettings  │
│              │  (Rotary Mixer UI)  │     (ObservableObj) │
│              └──────────┬──────────┘                    │
│                         │                               │
│              ┌──────────▼──────────┐                    │
│              │  AudioEngineManager │                    │
│              │                     │                    │
│              │  ┌───────────────┐  │                    │
│              │  │ Overlay Mode  │  │ ◄── VinylDSP #1   │
│              │  │ (noise gen)   │  │                    │
│              │  └───────────────┘  │                    │
│              │                     │                    │
│              │  ┌───────────────┐  │                    │
│              │  │Passthrough    │  │ ◄── VinylDSP #2   │
│              │  │(capture+play) │  │                    │
│              │  └───────────────┘  │                    │
│              └──────────┬──────────┘                    │
│                         │                               │
│              ┌──────────▼──────────┐                    │
│              │   DeviceManager     │                    │
│              │  (CoreAudio API)    │                    │
│              └─────────────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

## Component Map

### VinylAudioApp

Entry point. Creates a `MenuBarExtra` with `.window` style. Sets the activation policy to `.accessory` (no dock icon). Triggers crash recovery on launch via `DeviceManager.restorePersistedDevices()`.

### MenuBarView

SwiftUI view rendered inside the menu bar popover. Contains all UI components:

- **ChannelStrip** — toggle button with LED indicator and custom switch graphics
- **VUMeter** — 24-segment horizontal bar meter (L/R channels), color-coded green/yellow/red
- **RotaryKnob** — circular dial with scale notches, active arc, and drag gesture (270° rotation range, -135° to +135°)
- **PresetPill** — selectable preset button with amber highlight
- **RecordView** — animated spinning vinyl disc using `TimelineView`

All subviews are `private` to the file.

### AudioEngineManager

Manages the audio processing lifecycle. Owns two independent DSP instances to avoid thread contention when both modes run simultaneously.

**Overlay mode:** Single `AVAudioEngine` → `AVAudioSourceNode` generates noise → default output device.

**Passthrough mode:** Two `AVAudioEngine` instances:

```
System Audio → BlackHole (virtual device)
                    │
            ┌───────▼────────┐
            │ Capture Engine  │ ← inputNode tap (512 frames)
            │ (inputNode →    │
            │  silent mixer)  │
            └───────┬────────┘
                    │ AudioRingBuffer (L/R)
            ┌───────▼────────┐
            │ Playback Engine │ ← AVAudioSourceNode reads ring buffer
            │ (DSP processing │   → processPassthrough()
            │  → real output) │
            └────────────────┘
                    │
            Original speakers / headphones
```

Key design decisions:
- Two engines avoid the single-engine device routing problem where `AVAudioEngine` can't reliably use different input/output devices
- Playback device is set via `AudioUnitSetProperty(kAudioOutputUnitProperty_CurrentDevice)` **before** the engine starts, preventing any frames from going to BlackHole
- When overlay is active during passthrough, the overlay engine is pinned to the physical output device to prevent it from following the system default to BlackHole

### VinylDSP

Pure DSP engine, designed to be called from real-time audio threads.

**Constraints:**
- No heap allocations in render path
- No Objective-C message sends
- Custom xorshift64 RNG instead of system random
- Pre-allocated delay line buffers

**Signal chain (passthrough mode):**

```
Input → Wow & Flutter (variable delay) → Soft Saturation (tanh)
      → Low-pass Filter (one-pole) → +Noise → +Crackle → +Pops
      → +Rumble → ×Groove Modulation → Output
```

**Signal chain (overlay mode):**

```
Pink Noise + Crackle + Pops + Rumble → ×Groove Mod
→ Soft Saturation → ×Volume → Stereo Decorrelation
→ Low-pass Filter → Output
```

### DeviceManager

Stateless enum wrapping CoreAudio C APIs. Handles:
- Device enumeration (`AudioObjectGetPropertyData`)
- Default device get/set (`kAudioHardwarePropertyDefaultOutputDevice`)
- BlackHole detection (case-insensitive name matching)
- Crash recovery persistence via `UserDefaults`

### AudioRingBuffer

Thread-safe single-producer single-consumer circular buffer. Uses a heap-allocated `pthread_mutex_t` for synchronization between the capture thread (writer) and playback thread (reader). Handles underruns gracefully by zero-filling.

### VinylSettings

`ObservableObject` bridging UI controls to DSP parameters. Supports 4 presets and automatically clears the active preset when any slider is manually adjusted.

## Threading Model

```
Main Thread          Audio Thread 1       Audio Thread 2
───────────          ──────────────       ──────────────
MenuBarView          Capture Engine       Playback Engine
VinylSettings        └─ inputNode tap     └─ AVAudioSourceNode
AudioEngineManager     └─ ringBuffer.write  └─ ringBuffer.read
└─ meterTimer (30fps)                       └─ VinylDSP.processPassthrough
   └─ reads peakL/R                            └─ writes peakL/R
```

Peak metering values (`peakL`/`peakR`) are accessed across threads without locks. On Apple Silicon and x86-64, 32-bit float writes are atomic at the hardware level, making this safe in practice despite being technically undefined behavior in the Swift memory model.

## Dependencies

None. The app uses only Apple system frameworks:
- `SwiftUI` — UI
- `AVFoundation` — `AVAudioEngine`, `AVCaptureDevice`
- `CoreAudio` / `AudioToolbox` — device management, `AudioUnit` properties
- `AppKit` — `NSApplication` lifecycle
- `Darwin` — `pthread_mutex_t`
