# Vinyl Audio

A macOS menu bar app that applies real-time vinyl record simulation effects to your audio. Built with SwiftUI and Core Audio.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## What it does

Vinyl Audio sits in your menu bar and adds the warm, nostalgic character of vinyl records to any audio playing on your Mac. It works in two independent modes:

- **Vinyl Noise** — generates ambient vinyl noise (surface hiss, crackle, pops, rumble) overlaid on top of your audio
- **Routing** — captures system audio through a virtual loopback device, applies vinyl processing (warmth, wow & flutter, saturation), and outputs the result to your speakers

Both modes can run simultaneously for the full vinyl experience.

## Features

- Rotary mixer-style UI with drag-to-rotate knobs
- Real-time VU meters with green/yellow/red segmented display
- 6 adjustable effect parameters: Surface Noise, Crackle, Pops, Warmth, Wow & Flutter, Rumble
- 4 presets: Pristine, Well-Loved, Vintage, Flea Market
- Master volume control
- Independent routing and noise toggles with LED indicators
- Crash recovery — restores original audio devices on relaunch
- Zero-dependency — pure Swift, no third-party packages

## DSP Algorithms

| Effect | Algorithm |
|---|---|
| Surface Noise | Voss-McCartney pink noise (12 octave bands) |
| Crackle | Probabilistic trigger with exponential decay envelope |
| Pops | High-impulse events with randomized polarity |
| Warmth | Soft saturation (`tanh` waveshaper) + one-pole low-pass filter |
| Wow & Flutter | Variable delay line modulated by dual LFOs (0.8 Hz wow + 7 Hz flutter) |
| Rumble | Dual low-frequency oscillators (23 Hz + 31 Hz) |
| Groove Modulation | 0.55 Hz periodic level variation (simulates 33 RPM rotation) |
| Stereo Field | Delay-based decorrelation with micro-noise spread |

All DSP uses a real-time safe xorshift64 RNG — no heap allocations on the audio thread.

## Requirements

- macOS 14 (Sonoma) or later
- [BlackHole](https://existential.audio/blackhole/) virtual audio driver (required for Routing mode only; Vinyl Noise works without it)

## Installation

### From source

```bash
git clone https://github.com/YOUR_USERNAME/vinyl-audio.git
cd vinyl-audio
make package
open VinylAudio.app
```

### Install to /Applications

```bash
make install
```

### BlackHole setup (for Routing mode)

1. Install [BlackHole 2ch](https://existential.audio/blackhole/)
2. Launch Vinyl Audio
3. Toggle **ROUTING** — the app handles device switching automatically

When routing is active, the app temporarily sets your system output to BlackHole, captures the audio, processes it through the vinyl DSP chain, and outputs the result to your original speakers/headphones. When you toggle routing off (or quit the app), your original audio devices are restored.

## Usage

Click the vinyl disc icon in your menu bar to open the mixer panel.

| Control | What it does |
|---|---|
| **ROUTING** toggle | Routes system audio through the vinyl filter (requires BlackHole) |
| **VINYL NOISE** toggle | Adds ambient vinyl noise overlay |
| Rotary knobs | Adjust individual effect intensities (drag up/down) |
| MASTER slider | Controls overall output volume |
| Preset pills | One-click effect configurations |

## Architecture

```
Sources/VinylAudio/
├── VinylAudioApp.swift    # App entry point, menu bar setup
├── MenuBarView.swift      # Rotary mixer UI (knobs, VU, toggles)
├── AudioEngine.swift      # AVAudioEngine management (overlay + passthrough)
├── VinylDSP.swift         # All DSP algorithms (real-time safe)
├── VinylSettings.swift    # Observable settings + presets
├── DeviceManager.swift    # Core Audio device enumeration & routing
└── RingBuffer.swift       # Thread-safe SPSC circular buffer
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the detailed system design.

## Building

```bash
make build      # Debug build
make package    # Release build + .app bundle
make install    # Copy to /Applications
make clean      # Remove build artifacts
```

## How it works

### Overlay mode (Vinyl Noise)

A single `AVAudioEngine` with an `AVAudioSourceNode` generates vinyl noise directly and outputs to the default audio device. No system audio capture required.

### Passthrough mode (Routing)

Two separate `AVAudioEngine` instances:

1. **Capture engine** — sets system output to BlackHole, installs a tap on its `inputNode` to read audio from BlackHole, writes samples to a thread-safe ring buffer
2. **Playback engine** — reads from the ring buffer via `AVAudioSourceNode`, processes through the vinyl DSP chain, outputs to the original speakers/headphones

This two-engine architecture ensures independent device routing without feedback loops.

## License

[MIT](LICENSE)
