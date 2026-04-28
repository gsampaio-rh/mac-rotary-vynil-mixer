# Changelog: Mac Rotary Vynil Mixer

**Related:** [README](../README.md) | [Architecture](ARCHITECTURE.md)

## v1.1.0 — Analog UI Overhaul

**Date:** 2026-04-28

### UI

- **Analog VU meters** — replaced digital LED bar meters with needle-style analog gauges featuring cream face, arc scale with VU markings (-20 to +3), red zone indicator, glass overlay, pivot point, and signal LED indicators (green/amber/red)
- **Scalloped rotary knobs** — redesigned knobs with 12-lobe fluted body, brushed aluminum chrome cap with radial texture, angular edge bevel, center dimple, and groove ring (inspired by Condesa Lucia, Ecler WARM4, Bozak AR-4)
- **Night / Day theme** — manual toggle between dark panel (original) and Bozak AR-4 brushed silver mode; 17-property `MixerTheme` struct with SwiftUI `@Environment` propagation; smooth 0.3s animated transition; preference persisted via `UserDefaults`
- **Engraved section dividers** — two-tone groove lines simulating machined metal panel

### Architecture

- Introduced `MixerTheme` color system with `EnvironmentKey` for clean theme propagation through all components
- Added `isDarkMode` to `VinylSettings` with `UserDefaults` persistence

---

## v1.0.0 — Initial Release

**Date:** 2026-04-27

### Features

- **Menu bar app** — runs as a macOS accessory with no dock icon
- **Vinyl noise overlay** — generates ambient vinyl noise (surface hiss, crackle, pops, rumble) mixed on top of system audio output
- **Audio routing / passthrough** — captures system audio via BlackHole virtual device, processes through the vinyl DSP chain, outputs to original speakers/headphones
- **Independent toggles** — routing and vinyl noise can be enabled/disabled independently, both can run simultaneously
- **Rotary mixer UI** — dark mixer panel with 6 drag-to-rotate knobs, VU meters, LED-indicator toggles, and preset pills
- **4 presets** — Pristine, Well-Loved, Vintage, Flea Market
- **Real-time VU metering** — 24-segment L/R level meters updated at 30fps
- **Crash recovery** — persists original audio device IDs; restores them on relaunch if app terminated abnormally while routing was active

### DSP

- Pink noise via Voss-McCartney algorithm (12 octave bands)
- Crackle and pops with probabilistic triggers and exponential decay
- Wow & flutter via dual-LFO variable delay line
- Soft saturation (tanh waveshaper) for analog warmth
- One-pole low-pass filter for high-frequency rolloff
- Stereo decorrelation via delay-based spread
- Groove modulation simulating 33 RPM turntable rotation
- Real-time safe xorshift64 RNG (no heap allocations)

### Architecture

- Two-engine passthrough design (separate capture and playback AVAudioEngine instances) for reliable device routing
- Thread-safe ring buffer with pthread_mutex_t for inter-engine audio transfer
- Explicit device pinning via AudioUnitSetProperty before engine start to prevent feedback loops
- DeviceManager handles CoreAudio device enumeration, default device switching, and crash recovery persistence

### Technical

- Swift 5.9, macOS 14+
- SwiftUI MenuBarExtra with .window style
- Zero external dependencies
