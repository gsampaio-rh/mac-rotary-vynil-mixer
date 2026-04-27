import SwiftUI

private let amber = Color(red: 0.85, green: 0.65, blue: 0.30)
private let panelBg = Color(red: 0.04, green: 0.04, blue: 0.05)
private let sectionBg = Color(white: 0.06)
private let labelColor = Color(white: 0.50)
private let dimLabel = Color(white: 0.30)
private let vuGreen = Color(red: 0.29, green: 0.87, blue: 0.50)
private let vuYellow = Color(red: 0.98, green: 0.75, blue: 0.14)
private let vuRed = Color(red: 0.94, green: 0.27, blue: 0.27)
private let ledBlue = Color(red: 0.30, green: 0.52, blue: 1.0)

struct MenuBarView: View {
    @ObservedObject var settings: VinylSettings
    @ObservedObject var engine: AudioEngineManager

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            channelToggles
            vuSection
            knobSection("EQ") {
                MixerKnob(label: "HIGH", value: $settings.eqHigh, centered: true)
                MixerKnob(label: "MID", value: $settings.eqMid, centered: true)
                MixerKnob(label: "LOW", value: $settings.eqLow, centered: true)
            }
            knobSection("VINYL") {
                MixerKnob(label: "NOISE", value: $settings.surfaceNoise)
                MixerKnob(label: "CRACKLE", value: $settings.crackleAmount)
                MixerKnob(label: "POPS", value: $settings.popAmount)
            }
            knobSection("CHARACTER") {
                MixerKnob(label: "WARMTH", value: $settings.warmth)
                MixerKnob(label: "WOW/FLT", value: $settings.wowFlutter)
                MixerKnob(label: "RUMBLE", value: $settings.rumble)
            }
            filterSection
            masterStrip
            presetStrip
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
            RecordSpinner(isSpinning: engine.isRunning)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 0) {
                Text("VINYL AUDIO")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(amber)
                Text("professional mixer")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(dimLabel)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(sectionBg)
    }

    // MARK: - Channel Toggles

    private var channelToggles: some View {
        HStack(spacing: 8) {
            ChannelToggle(
                label: "ROUTING",
                sublabel: engine.blackHoleAvailable ? "BlackHole" : "No driver",
                isActive: engine.isPassthroughActive,
                enabled: engine.blackHoleAvailable
            ) { engine.togglePassthrough(settings: settings) }

            ChannelToggle(
                label: "VINYL NOISE",
                sublabel: "Overlay",
                isActive: engine.isOverlayActive,
                enabled: true
            ) { engine.toggleOverlay(settings: settings) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - VU

    private var vuSection: some View {
        VUMeter(levelL: engine.levelL, levelR: engine.levelR)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
    }

    // MARK: - Knob Section Builder

    private func knobSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 2) {
            sectionHeader(title)
            HStack(spacing: 0) { content() }
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }
        .background(sectionBg)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    // MARK: - Filter + Reverb

    private var filterSection: some View {
        VStack(spacing: 2) {
            sectionHeader("EFFECTS")
            HStack(spacing: 0) {
                MixerKnob(label: "REVERB", value: $settings.reverb)
                MixerKnob(label: "FILTER", value: $settings.filterCutoff)
                MixerKnob(label: "RESON", value: $settings.filterResonance)
            }
            .padding(.horizontal, 4)

            // Filter mode toggle
            HStack(spacing: 0) {
                Spacer()
                FilterModeSwitch(isHighPass: $settings.filterIsHighPass)
                Spacer()
            }
            .padding(.bottom, 6)
        }
        .background(sectionBg)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    // MARK: - Master

    private var masterStrip: some View {
        HStack(spacing: 6) {
            Text("MASTER")
                .font(.system(size: 7, weight: .bold))
                .tracking(1)
                .foregroundStyle(dimLabel)
                .frame(width: 40)

            Image(systemName: "speaker.fill")
                .font(.system(size: 7))
                .foregroundStyle(dimLabel)

            Slider(value: $settings.masterVolume, in: 0...1)
                .tint(amber)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 7))
                .foregroundStyle(dimLabel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Presets

    private var presetStrip: some View {
        HStack(spacing: 4) {
            ForEach(VinylPreset.allCases) { preset in
                PresetChip(
                    title: preset.rawValue,
                    isSelected: settings.selectedPreset == preset
                ) {
                    settings.applyPreset(preset)
                    engine.updateParameters(settings.dspParameters)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if let msg = engine.error {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 8))
                Text(msg)
                    .font(.system(size: 8))
                    .foregroundStyle(dimLabel)
                    .lineLimit(1)
            }
            Spacer()
            Button("QUIT") {
                engine.stop()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 7, weight: .bold))
            .tracking(1)
            .foregroundStyle(dimLabel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            Text(title)
                .font(.system(size: 7, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(dimLabel)
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }
}

// MARK: - Channel Toggle

private struct ChannelToggle: View {
    let label: String
    let sublabel: String
    let isActive: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: { if enabled { action() } }) {
            VStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(enabled ? labelColor : dimLabel)

                Circle()
                    .fill(isActive ? ledBlue : Color(white: 0.10))
                    .frame(width: 7, height: 7)
                    .shadow(color: isActive ? ledBlue.opacity(0.7) : .clear, radius: 5)

                Capsule()
                    .fill(isActive ? amber.opacity(0.25) : Color(white: 0.06))
                    .frame(width: 34, height: 16)
                    .overlay(
                        Circle()
                            .fill(isActive ? amber : Color(white: 0.22))
                            .frame(width: 12, height: 12)
                            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                            .offset(x: isActive ? 8 : -8)
                    )
                    .animation(.easeInOut(duration: 0.12), value: isActive)

                Text(sublabel)
                    .font(.system(size: 7))
                    .foregroundStyle(dimLabel)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(white: 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.white.opacity(0.03), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.45)
    }
}

// MARK: - VU Meter

private struct VUMeter: View {
    let levelL: Float
    let levelR: Float
    private let segments = 24

    var body: some View {
        VStack(spacing: 2) {
            meterRow(level: levelL, label: "L")
            meterRow(level: levelR, label: "R")
        }
    }

    private func meterRow(level: Float, label: String) -> some View {
        HStack(spacing: 1.2) {
            Text(label)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(dimLabel)
                .frame(width: 8)
            ForEach(0..<segments, id: \.self) { i in
                let ratio = Float(i) / Float(segments)
                RoundedRectangle(cornerRadius: 1)
                    .fill(level > ratio ? segmentColor(ratio) : segmentColor(ratio).opacity(0.08))
                    .frame(height: 6)
            }
        }
    }

    private func segmentColor(_ r: Float) -> Color {
        if r < 0.55 { return vuGreen }
        if r < 0.78 { return vuYellow }
        return vuRed
    }
}

// MARK: - Mixer Knob (Chrome)

private struct MixerKnob: View {
    let label: String
    @Binding var value: Float
    var centered: Bool = false

    @State private var dragStart: Float?
    private let size: CGFloat = 38

    private var angle: Double {
        -135 + Double(value) * 270
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 6, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(labelColor)

            ZStack {
                // Recessed well
                Circle()
                    .fill(Color(white: 0.025))
                    .frame(width: size + 12, height: size + 12)

                // Dot scale markings
                ForEach(0..<11, id: \.self) { i in
                    let a = -135.0 + Double(i) / 10.0 * 270.0
                    let isMajor = i == 0 || i == 5 || i == 10
                    Circle()
                        .fill(Color.white.opacity(isMajor ? 0.45 : 0.15))
                        .frame(width: isMajor ? 2.5 : 1.5,
                               height: isMajor ? 2.5 : 1.5)
                        .offset(y: -(size / 2 + 4))
                        .rotationEffect(.degrees(a))
                }

                // Active arc
                if !centered {
                    Circle()
                        .trim(from: 0, to: CGFloat(value) * 0.75)
                        .stroke(amber.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: size + 3, height: size + 3)
                        .rotationEffect(.degrees(135))
                }

                // Chrome knob body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.38), Color(white: 0.14)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 2)

                // Inner chrome ring
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    .frame(width: size - 5, height: size - 5)

                // Center cap highlight
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.08), .clear],
                            center: .init(x: 0.35, y: 0.30),
                            startRadius: 0,
                            endRadius: size * 0.35
                        )
                    )
                    .frame(width: size - 4, height: size - 4)

                // White indicator line
                Capsule()
                    .fill(.white)
                    .frame(width: 2, height: size * 0.30)
                    .offset(y: -(size * 0.22))
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: size + 14, height: size + 14)
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

            Text("\(Int(value * 100))")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(amber)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Filter Mode Switch

private struct FilterModeSwitch: View {
    @Binding var isHighPass: Bool

    var body: some View {
        HStack(spacing: 0) {
            modeLabel("LP", active: !isHighPass)
            Toggle("", isOn: $isHighPass)
                .toggleStyle(.switch)
                .tint(ledBlue)
                .labelsHidden()
                .scaleEffect(0.55)
                .frame(width: 40)
            modeLabel("HP", active: isHighPass)
        }
    }

    private func modeLabel(_ text: String, active: Bool) -> some View {
        Text(text)
            .font(.system(size: 7, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(active ? ledBlue : dimLabel)
    }
}

// MARK: - Preset Chip

private struct PresetChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? amber.opacity(0.18) : Color(white: 0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? amber.opacity(0.5) : Color.white.opacity(0.04), lineWidth: 1)
                )
                .foregroundStyle(isSelected ? amber : labelColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Record Spinner

private struct RecordSpinner: View {
    let isSpinning: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isSpinning)) { ctx in
            let rot = isSpinning ? ctx.date.timeIntervalSinceReferenceDate * 200 : 0
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color(white: 0.14), Color(white: 0.03)],
                        center: .center, startRadius: 3, endRadius: 18
                    ))
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
                        .padding(CGFloat(3 + i * 3))
                }
                Ellipse()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 20, height: 6)
                    .offset(y: -6)
                    .rotationEffect(.degrees(rot.truncatingRemainder(dividingBy: 360)))
                Circle().fill(amber).frame(width: 8, height: 8)
                Circle().fill(Color(white: 0.08)).frame(width: 2, height: 2)
            }
        }
    }
}
