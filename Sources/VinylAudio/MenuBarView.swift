import SwiftUI

// MARK: - Theme-independent accent colors

private let amber = Color(red: 0.85, green: 0.65, blue: 0.30)
private let ledBlue = Color(red: 0.30, green: 0.52, blue: 1.0)
private let meterCream = Color(red: 0.93, green: 0.90, blue: 0.83)
private let meterRed = Color(red: 0.80, green: 0.12, blue: 0.10)

// MARK: - Mixer Theme

struct MixerTheme {
    let panelBg: Color
    let sectionBg: Color
    let labelColor: Color
    let dimLabel: Color
    let cardBg: Color
    let cardStroke: Color
    let wellColor: Color
    let wellColorDeep: Color
    let dotMajorOpacity: Double
    let dotMinorOpacity: Double
    let bezelTop: Color
    let bezelBottom: Color
    let inactiveLED: Color
    let engraveTop: Color
    let engraveBottom: Color
    let switchTrack: Color
    let switchThumb: Color

    static let night = MixerTheme(
        panelBg: Color(red: 0.04, green: 0.04, blue: 0.05),
        sectionBg: Color(white: 0.06),
        labelColor: Color(white: 0.50),
        dimLabel: Color(white: 0.30),
        cardBg: Color(white: 0.04),
        cardStroke: Color.white.opacity(0.03),
        wellColor: Color(white: 0.04),
        wellColorDeep: Color(white: 0.015),
        dotMajorOpacity: 0.45,
        dotMinorOpacity: 0.15,
        bezelTop: Color(white: 0.12),
        bezelBottom: Color(white: 0.05),
        inactiveLED: Color(white: 0.08),
        engraveTop: Color.black.opacity(0.3),
        engraveBottom: Color.white.opacity(0.04),
        switchTrack: Color(white: 0.06),
        switchThumb: Color(white: 0.22)
    )

    static let day = MixerTheme(
        panelBg: Color(red: 0.73, green: 0.70, blue: 0.66),
        sectionBg: Color(red: 0.69, green: 0.66, blue: 0.62),
        labelColor: Color(white: 0.12),
        dimLabel: Color(white: 0.38),
        cardBg: Color(red: 0.64, green: 0.62, blue: 0.58),
        cardStroke: Color.black.opacity(0.08),
        wellColor: Color(white: 0.55),
        wellColorDeep: Color(white: 0.48),
        dotMajorOpacity: 0.80,
        dotMinorOpacity: 0.35,
        bezelTop: Color(white: 0.52),
        bezelBottom: Color(white: 0.40),
        inactiveLED: Color(white: 0.52),
        engraveTop: Color.white.opacity(0.30),
        engraveBottom: Color.black.opacity(0.10),
        switchTrack: Color(white: 0.55),
        switchThumb: Color(white: 0.38)
    )
}

private struct MixerThemeKey: EnvironmentKey {
    static let defaultValue = MixerTheme.night
}

extension EnvironmentValues {
    var mixerTheme: MixerTheme {
        get { self[MixerThemeKey.self] }
        set { self[MixerThemeKey.self] = newValue }
    }
}

// MARK: - Main View

struct MenuBarView: View {
    @ObservedObject var settings: VinylSettings
    @ObservedObject var engine: AudioEngineManager

    private var theme: MixerTheme {
        settings.isDarkMode ? .night : .day
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            vuSection
            channelToggles
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
        .background(theme.panelBg)
        .environment(\.mixerTheme, theme)
        .animation(.easeInOut(duration: 0.3), value: settings.isDarkMode)
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
                Text("rotary mixer")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(theme.dimLabel)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.sectionBg)
    }

    // MARK: - VU Meters

    private var vuSection: some View {
        HStack(spacing: 8) {
            AnalogVUMeter(level: engine.levelL, channel: "LEFT")
            AnalogVUMeter(level: engine.levelR, channel: "RIGHT")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.sectionBg)
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
        .padding(.vertical, 4)
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
                .padding(.bottom, 2)
        }
        .background(theme.sectionBg)
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

            HStack(spacing: 0) {
                Spacer()
                FilterModeSwitch(isHighPass: $settings.filterIsHighPass)
                Spacer()
            }
            .padding(.bottom, 4)
        }
        .background(theme.sectionBg)
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    // MARK: - Master

    private var masterStrip: some View {
        HStack(spacing: 6) {
            Text("MASTER")
                .font(.system(size: 7, weight: .bold))
                .tracking(1)
                .foregroundStyle(theme.dimLabel)
                .frame(width: 40)

            Image(systemName: "speaker.fill")
                .font(.system(size: 7))
                .foregroundStyle(theme.dimLabel)

            Slider(value: $settings.masterVolume, in: 0...1)
                .tint(amber)

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 7))
                .foregroundStyle(theme.dimLabel)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
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
        .padding(.vertical, 5)
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
                    .foregroundStyle(theme.dimLabel)
                    .lineLimit(1)
            }
            Spacer()

            Button {
                settings.isDarkMode.toggle()
            } label: {
                Image(systemName: settings.isDarkMode ? "sun.max" : "moon.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.dimLabel)
            }
            .buttonStyle(.plain)

            Button("QUIT") {
                engine.stop()
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 7, weight: .bold))
            .tracking(1)
            .foregroundStyle(theme.dimLabel)
            .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            engravedLine
            Text(title)
                .font(.system(size: 7, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(theme.dimLabel)
            engravedLine
        }
        .padding(.horizontal, 10)
        .padding(.top, 3)
    }

    private var engravedLine: some View {
        VStack(spacing: 0) {
            Rectangle().fill(theme.engraveTop).frame(height: 0.5)
            Rectangle().fill(theme.engraveBottom).frame(height: 0.5)
        }
    }
}

// MARK: - Analog VU Meter

private struct AnalogVUMeter: View {
    let level: Float
    let channel: String
    @Environment(\.mixerTheme) private var theme

    private let meterW: CGFloat = 146
    private let meterH: CGFloat = 78

    private var pivotX: CGFloat { meterW / 2 }
    private var pivotY: CGFloat { meterH - 9 }

    private var needleAngle: Double {
        -45 + Double(max(0, min(1, level))) * 90
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(channel)
                .font(.system(size: 7, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(amber)

            signalLEDs

            ZStack {
                meterBezel
                meterFace
                meterScaleCanvas
                meterNeedle
                meterPivot
                meterGlass
            }
            .frame(width: meterW, height: meterH)
        }
    }

    private var signalLEDs: some View {
        HStack(spacing: 3) {
            signalDot(active: level > 0.02, color: Color(red: 0.29, green: 0.87, blue: 0.50))
            signalDot(active: level > 0.50, color: amber)
            signalDot(active: level > 0.85, color: meterRed)
        }
    }

    private func signalDot(active: Bool, color: Color) -> some View {
        Circle()
            .fill(active ? color : theme.inactiveLED)
            .frame(width: 4, height: 4)
            .shadow(color: active ? color.opacity(0.7) : .clear, radius: 3)
    }

    private var meterBezel: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(
                LinearGradient(
                    colors: [theme.bezelTop, theme.bezelBottom],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
    }

    private var meterFace: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                RadialGradient(
                    colors: [meterCream, meterCream.opacity(0.90)],
                    center: .init(x: 0.5, y: 0.35),
                    startRadius: 5, endRadius: 80
                )
            )
            .padding(3)
    }

    private var meterScaleCanvas: some View {
        Canvas { ctx, size in
            let px = size.width / 2
            let py = size.height - 6
            let r: CGFloat = 46

            drawArc(ctx: ctx, px: px, py: py, r: r)
            drawRedZone(ctx: ctx, px: px, py: py, r: r)
            drawTicks(ctx: ctx, px: px, py: py, r: r)
            drawVULabel(ctx: ctx, px: px, py: py)
        }
        .padding(3)
    }

    private func drawArc(ctx: GraphicsContext, px: CGFloat, py: CGFloat, r: CGFloat) {
        var arc = Path()
        arc.addArc(
            center: CGPoint(x: px, y: py), radius: r,
            startAngle: .degrees(225), endAngle: .degrees(315),
            clockwise: false
        )
        ctx.stroke(arc, with: .color(.black.opacity(0.25)), lineWidth: 0.8)
    }

    private func drawRedZone(ctx: GraphicsContext, px: CGFloat, py: CGFloat, r: CGFloat) {
        var redArc = Path()
        redArc.addArc(
            center: CGPoint(x: px, y: py), radius: r - 3,
            startAngle: .degrees(225 + 0.77 * 90), endAngle: .degrees(315),
            clockwise: false
        )
        ctx.stroke(redArc, with: .color(meterRed.opacity(0.55)), lineWidth: 2)
    }

    private func drawTicks(ctx: GraphicsContext, px: CGFloat, py: CGFloat, r: CGFloat) {
        let marks: [(label: String, pos: Double, major: Bool, red: Bool)] = [
            ("-20", 0.00, true, false), ("", 0.07, false, false),
            ("", 0.14, false, false),   ("-10", 0.22, true, false),
            ("", 0.29, false, false),   ("-7", 0.36, true, false),
            ("", 0.42, false, false),   ("-5", 0.48, true, false),
            ("", 0.54, false, false),   ("-3", 0.60, true, false),
            ("", 0.65, false, false),   ("", 0.70, false, false),
            ("0", 0.77, true, true),    ("", 0.85, false, true),
            ("", 0.92, false, true),    ("+3", 1.00, true, true),
        ]

        for mark in marks {
            let deg = 225.0 + mark.pos * 90.0
            let rad = deg * .pi / 180.0
            let tickLen: CGFloat = mark.major ? 5 : 3
            let tickW: CGFloat = mark.major ? 1.0 : 0.6
            let color: Color = mark.red ? meterRed : .black.opacity(0.6)

            let outer = CGPoint(x: px + (r + 1) * cos(rad), y: py + (r + 1) * sin(rad))
            let inner = CGPoint(x: px + (r - tickLen) * cos(rad), y: py + (r - tickLen) * sin(rad))

            var tick = Path()
            tick.move(to: inner)
            tick.addLine(to: outer)
            ctx.stroke(tick, with: .color(color), lineWidth: tickW)

            if mark.major && !mark.label.isEmpty {
                let lr = r + 9
                let lp = CGPoint(x: px + lr * cos(rad), y: py + lr * sin(rad))
                let txt = Text(mark.label)
                    .font(.system(size: 5.5, weight: .semibold))
                    .foregroundColor(mark.red ? meterRed : .black.opacity(0.55))
                ctx.draw(txt, at: lp)
            }
        }
    }

    private func drawVULabel(ctx: GraphicsContext, px: CGFloat, py: CGFloat) {
        let vu = Text("VU")
            .font(.system(size: 7, weight: .heavy, design: .serif))
            .foregroundColor(.black.opacity(0.22))
        ctx.draw(vu, at: CGPoint(x: px, y: py - 18))
    }

    private var meterNeedle: some View {
        Capsule()
            .fill(Color(red: 0.10, green: 0.06, blue: 0.04))
            .frame(width: 1.5, height: 44)
            .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
            .offset(y: -22)
            .rotationEffect(.degrees(needleAngle))
            .position(x: pivotX, y: pivotY)
            .animation(.easeOut(duration: 0.12), value: level)
    }

    private var meterPivot: some View {
        ZStack {
            Circle().fill(Color(white: 0.25)).frame(width: 7, height: 7)
            Circle().fill(Color(white: 0.10)).frame(width: 4, height: 4)
        }
        .position(x: pivotX, y: pivotY)
    }

    private var meterGlass: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.10), .clear, .clear],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .padding(3)
            .allowsHitTesting(false)
    }
}

// MARK: - Channel Toggle

private struct ChannelToggle: View {
    let label: String
    let sublabel: String
    let isActive: Bool
    let enabled: Bool
    let action: () -> Void
    @Environment(\.mixerTheme) private var theme

    var body: some View {
        Button(action: { if enabled { action() } }) {
            VStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 8, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(enabled ? theme.labelColor : theme.dimLabel)

                Circle()
                    .fill(isActive ? ledBlue : theme.inactiveLED)
                    .frame(width: 7, height: 7)
                    .shadow(color: isActive ? ledBlue.opacity(0.7) : .clear, radius: 5)

                Capsule()
                    .fill(isActive ? amber.opacity(0.25) : theme.switchTrack)
                    .frame(width: 34, height: 16)
                    .overlay(
                        Circle()
                            .fill(isActive ? amber : theme.switchThumb)
                            .frame(width: 12, height: 12)
                            .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                            .offset(x: isActive ? 8 : -8)
                    )
                    .animation(.easeInOut(duration: 0.12), value: isActive)

                Text(sublabel)
                    .font(.system(size: 7))
                    .foregroundStyle(theme.dimLabel)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(theme.cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(theme.cardStroke, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.45)
    }
}

// MARK: - Mixer Knob (Chrome Cap)

private struct MixerKnob: View {
    let label: String
    @Binding var value: Float
    var centered: Bool = false
    @Environment(\.mixerTheme) private var theme

    @State private var dragStart: Float?
    private let size: CGFloat = 40
    private let capSize: CGFloat = 24

    private var angle: Double {
        -135 + Double(value) * 270
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 6, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(theme.labelColor)

            ZStack {
                knobWell
                scaleMarks
                if !centered { valueArc }
                knobBody
                chromeCap
                indicatorLine
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

    private var knobWell: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [theme.wellColor, theme.wellColorDeep],
                    center: .center, startRadius: 5, endRadius: 28
                )
            )
            .frame(width: size + 12, height: size + 12)
    }

    private var scaleMarks: some View {
        ForEach(0..<11, id: \.self) { i in
            let a = -135.0 + Double(i) / 10.0 * 270.0
            let isMajor = i == 0 || i == 5 || i == 10
            Circle()
                .fill(Color.white.opacity(isMajor ? theme.dotMajorOpacity : theme.dotMinorOpacity))
                .frame(width: isMajor ? 2.5 : 1.5,
                       height: isMajor ? 2.5 : 1.5)
                .offset(y: -(size / 2 + 4))
                .rotationEffect(.degrees(a))
        }
    }

    private var valueArc: some View {
        Circle()
            .trim(from: 0, to: CGFloat(value) * 0.75)
            .stroke(amber.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .frame(width: size + 3, height: size + 3)
            .rotationEffect(.degrees(135))
    }

    private var knobBody: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.11), Color(white: 0.04)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 12, height: 12)
                    .offset(y: -(size / 2 - 3))
                    .rotationEffect(.degrees(Double(i) * 30))
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.08), Color(white: 0.04)],
                        center: .center, startRadius: 2, endRadius: 20
                    )
                )
                .frame(width: size - 6, height: size - 6)

            Circle()
                .stroke(Color.black.opacity(0.6), lineWidth: 1.2)
                .frame(width: capSize + 3, height: capSize + 3)
        }
        .shadow(color: .black.opacity(0.55), radius: 3, y: 2)
    }

    private var chromeCap: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.54), Color(white: 0.40), Color(white: 0.48)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: capSize, height: capSize)

            ForEach(3..<Int(capSize / 2), id: \.self) { r in
                Circle()
                    .stroke(
                        Color.white.opacity(r % 3 == 0 ? 0.09 : 0.03),
                        lineWidth: 0.5
                    )
                    .frame(width: CGFloat(r) * 2, height: CGFloat(r) * 2)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.25), .clear],
                        center: .init(x: 0.32, y: 0.28),
                        startRadius: 0, endRadius: capSize * 0.35
                    )
                )
                .frame(width: capSize - 2, height: capSize - 2)

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04),
                            Color.black.opacity(0.10),
                            Color.white.opacity(0.14),
                        ],
                        center: .center
                    ),
                    lineWidth: 0.8
                )
                .frame(width: capSize - 1, height: capSize - 1)

            Circle()
                .fill(Color(white: 0.30))
                .frame(width: 3, height: 3)
        }
    }

    private var indicatorLine: some View {
        Capsule()
            .fill(.white)
            .frame(width: 2.5, height: size * 0.35)
            .offset(y: -(size * 0.25))
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Filter Mode Switch

private struct FilterModeSwitch: View {
    @Binding var isHighPass: Bool
    @Environment(\.mixerTheme) private var theme

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
            .foregroundStyle(active ? ledBlue : theme.dimLabel)
    }
}

// MARK: - Preset Chip

private struct PresetChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.mixerTheme) private var theme

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? amber.opacity(0.18) : theme.cardBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? amber.opacity(0.5) : theme.cardStroke, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? amber : theme.labelColor)
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
