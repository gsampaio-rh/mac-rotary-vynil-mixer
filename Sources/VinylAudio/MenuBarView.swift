import SwiftUI

private let amber = Color(red: 0.85, green: 0.65, blue: 0.30)
private let panelBg = Color(white: 0.07)
private let labelColor = Color(white: 0.45)
private let vuGreen = Color(red: 0.29, green: 0.87, blue: 0.50)
private let vuYellow = Color(red: 0.98, green: 0.75, blue: 0.14)
private let vuRed = Color(red: 0.94, green: 0.27, blue: 0.27)

struct MenuBarView: View {
    @ObservedObject var settings: VinylSettings
    @ObservedObject var engine: AudioEngineManager

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            mixerDivider
            toggleStrips
            mixerDivider
            vuSection
            mixerDivider
            knobGrid
            mixerDivider
            masterStrip
            mixerDivider
            presetStrip
            mixerDivider
            footer
        }
        .frame(width: 340)
        .background(panelBg)
        .onChange(of: settings.dspParameters) {
            engine.updateParameters(settings.dspParameters)
        }
    }

    // MARK: - Title

    private var titleBar: some View {
        HStack(spacing: 10) {
            RecordView(isSpinning: engine.isRunning)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 1) {
                Text("VINYL AUDIO")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(amber)
                Text("rotary mixer")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(labelColor)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Toggle Strips

    private var toggleStrips: some View {
        HStack(spacing: 8) {
            ChannelStrip(
                label: "ROUTING",
                sublabel: engine.blackHoleAvailable ? "BlackHole" : "No driver",
                isActive: engine.isPassthroughActive,
                enabled: engine.blackHoleAvailable
            ) {
                engine.togglePassthrough(settings: settings)
            }

            ChannelStrip(
                label: "VINYL NOISE",
                sublabel: "Overlay",
                isActive: engine.isOverlayActive,
                enabled: true
            ) {
                engine.toggleOverlay(settings: settings)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - VU Meter

    private var vuSection: some View {
        VUMeter(levelL: engine.levelL, levelR: engine.levelR)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
    }

    // MARK: - Knobs

    private var knobGrid: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                RotaryKnob(label: "NOISE", value: $settings.surfaceNoise)
                    .frame(maxWidth: .infinity)
                RotaryKnob(label: "CRACKLE", value: $settings.crackleAmount)
                    .frame(maxWidth: .infinity)
                RotaryKnob(label: "POPS", value: $settings.popAmount)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: 0) {
                RotaryKnob(label: "WARMTH", value: $settings.warmth)
                    .frame(maxWidth: .infinity)
                RotaryKnob(label: "WOW/FLT", value: $settings.wowFlutter)
                    .frame(maxWidth: .infinity)
                RotaryKnob(label: "RUMBLE", value: $settings.rumble)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Master

    private var masterStrip: some View {
        VStack(spacing: 4) {
            Text("MASTER")
                .font(.system(size: 8, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(labelColor)

            HStack(spacing: 6) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(labelColor)

                Slider(value: $settings.masterVolume, in: 0...1)
                    .tint(amber)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(labelColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Presets

    private var presetStrip: some View {
        HStack(spacing: 4) {
            ForEach(VinylPreset.allCases) { preset in
                PresetPill(
                    title: preset.rawValue,
                    isSelected: settings.selectedPreset == preset
                ) {
                    settings.applyPreset(preset)
                    engine.updateParameters(settings.dspParameters)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let msg = engine.error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 9))
                Text(msg)
                    .font(.system(size: 9))
                    .foregroundStyle(labelColor)
                    .lineLimit(1)
            }

            Spacer()

            Button("QUIT") {
                engine.stop()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 8, weight: .bold))
            .tracking(1)
            .foregroundStyle(labelColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var mixerDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }
}

// MARK: - Channel Strip Toggle

private struct ChannelStrip: View {
    let label: String
    let sublabel: String
    let isActive: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .foregroundStyle(enabled ? Color(white: 0.6) : Color(white: 0.3))

                // LED
                Circle()
                    .fill(isActive ? Color.green : Color(white: 0.12))
                    .frame(width: 8, height: 8)
                    .shadow(color: isActive ? .green.opacity(0.6) : .clear, radius: 6)
                    .overlay(
                        Circle()
                            .fill(isActive ? Color.green.opacity(0.4) : .clear)
                            .frame(width: 14, height: 14)
                            .blur(radius: 4)
                    )

                // Toggle groove
                Capsule()
                    .fill(isActive ? amber.opacity(0.25) : Color(white: 0.08))
                    .frame(width: 36, height: 18)
                    .overlay(
                        Circle()
                            .fill(isActive ? amber : Color(white: 0.25))
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                            .offset(x: isActive ? 8 : -8),
                        alignment: .center
                    )
                    .animation(.easeInOut(duration: 0.15), value: isActive)

                Text(sublabel)
                    .font(.system(size: 8))
                    .foregroundStyle(Color(white: 0.3))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(white: 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.5)
    }
}

// MARK: - VU Meter

private struct VUMeter: View {
    let levelL: Float
    let levelR: Float
    private let segments = 24

    var body: some View {
        VStack(spacing: 3) {
            meterRow(level: levelL, label: "L")
            meterRow(level: levelR, label: "R")
        }
    }

    private func meterRow(level: Float, label: String) -> some View {
        HStack(spacing: 1.5) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(white: 0.35))
                .frame(width: 10)

            ForEach(0..<segments, id: \.self) { i in
                let threshold = Float(i) / Float(segments)
                let lit = level > threshold
                let color = segmentColor(Float(i) / Float(segments))

                RoundedRectangle(cornerRadius: 1)
                    .fill(lit ? color : color.opacity(0.1))
                    .frame(height: 7)
            }
        }
    }

    private func segmentColor(_ ratio: Float) -> Color {
        if ratio < 0.55 { return vuGreen }
        if ratio < 0.78 { return vuYellow }
        return vuRed
    }
}

// MARK: - Rotary Knob

private struct RotaryKnob: View {
    let label: String
    @Binding var value: Float

    @State private var dragStart: Float?

    private let knobSize: CGFloat = 46
    private let minAngle: Double = -135
    private let maxAngle: Double = 135

    private var angle: Double {
        minAngle + Double(value) * (maxAngle - minAngle)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Outer ring
                Circle()
                    .fill(Color(white: 0.05))
                    .frame(width: knobSize + 10, height: knobSize + 10)

                // Scale notches
                ForEach(0..<11, id: \.self) { i in
                    let a = minAngle + Double(i) / 10.0 * (maxAngle - minAngle)
                    Capsule()
                        .fill(Color.white.opacity(i % 5 == 0 ? 0.28 : 0.10))
                        .frame(width: 1.5, height: i % 5 == 0 ? 5 : 3)
                        .offset(y: -(knobSize / 2 + 2))
                        .rotationEffect(.degrees(a))
                }

                // Active arc
                Circle()
                    .trim(from: 0, to: CGFloat(value) * 0.75)
                    .stroke(
                        amber.opacity(0.35),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: knobSize + 4, height: knobSize + 4)
                    .rotationEffect(.degrees(135))

                // Knob body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.22), Color(white: 0.11)],
                            center: .init(x: 0.35, y: 0.30),
                            startRadius: 0,
                            endRadius: knobSize * 0.5
                        )
                    )
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)

                // Indicator
                Capsule()
                    .fill(amber)
                    .frame(width: 2.5, height: knobSize * 0.28)
                    .offset(y: -(knobSize * 0.22))
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: knobSize + 14, height: knobSize + 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        if dragStart == nil { dragStart = value }
                        let delta = Float(-g.translation.height) / 120
                        value = max(0, min(1, (dragStart ?? 0) + delta))
                    }
                    .onEnded { _ in dragStart = nil }
            )

            Text(label)
                .font(.system(size: 7, weight: .bold))
                .tracking(1)
                .foregroundStyle(labelColor)

            Text("\(Int(value * 100))")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(amber)
        }
    }
}

// MARK: - Preset Pill

private struct PresetPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? amber.opacity(0.2) : Color(white: 0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            isSelected ? amber.opacity(0.6) : Color.white.opacity(0.06),
                            lineWidth: 1
                        )
                )
                .foregroundStyle(isSelected ? amber : Color(white: 0.5))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Spinning Record

private struct RecordView: View {
    let isSpinning: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isSpinning)) { ctx in
            let angle = isSpinning
                ? ctx.date.timeIntervalSinceReferenceDate * 200
                : 0

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.15), Color(white: 0.04)],
                            center: .center,
                            startRadius: 4,
                            endRadius: 20
                        )
                    )

                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
                        .padding(CGFloat(4 + i * 3))
                }

                Ellipse()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 24, height: 7)
                    .offset(y: -8)
                    .rotationEffect(.degrees(angle.truncatingRemainder(dividingBy: 360)))

                Circle()
                    .fill(amber)
                    .frame(width: 10, height: 10)

                Circle()
                    .fill(Color(white: 0.1))
                    .frame(width: 2.5, height: 2.5)
            }
        }
    }
}
