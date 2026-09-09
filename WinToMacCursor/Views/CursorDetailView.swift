import AppKit
import SwiftUI

public struct CursorDetailView: View {
    @ObservedObject var item: CursorItem
    @ObservedObject private var langManager = LanguageManager.shared
    @State private var currentFrameIndex: Int = 0
    @State private var isPlaying: Bool = true
    @State private var speedMultiplier: Double = 1.0
    @State private var showHotspotMarker: Bool = true
    @State private var backgroundMode: BackgroundMode = .checkerboard
    @State private var timer: Timer?

    public enum BackgroundMode: String, CaseIterable, Identifiable {
        case checkerboard = "checkerboard"
        case light = "light"
        case dark = "dark"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .checkerboard: return L10n.tr("bg_checkerboard")
            case .light: return L10n.tr("bg_light")
            case .dark: return L10n.tr("bg_dark")
            }
        }
    }

    public init(item: CursorItem) {
        self.item = item
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(item.name)
                                .font(.title2)
                                .bold()
                            
                            if item.isAnimated {
                                Text(L10n.tr("frames_count_badge", item.frames.count))
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                            }
                        }
                        
                        Text(item.role.localizedName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Background selector
                    Picker("", selection: $backgroundMode) {
                        ForEach(BackgroundMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: langManager.effectiveLanguageIsChinese ? 180 : 220)
                    .id("bg_picker_\(langManager.selectedLanguageRaw)_\(langManager.effectiveLanguageIsChinese)")
                }
                
                // Magnified Visualizer
                HStack(alignment: .top, spacing: 20) {
                    // Preview Box
                    ZStack {
                        // Background
                        previewBackground
                        
                        // Cursor Image (Scaled)
                        if let currentFrame = activeFrame {
                            GeometryReader { geo in
                                let scale: CGFloat = 4.0
                                let drawW = currentFrame.size.width * scale
                                let drawH = currentFrame.size.height * scale
                                let originX = (geo.size.width - drawW) / 2
                                let originY = (geo.size.height - drawH) / 2
                                
                                ZStack(alignment: .topLeading) {
                                    Image(nsImage: currentFrame.image)
                                        .interpolation(.none)
                                        .resizable()
                                        .frame(width: drawW, height: drawH)
                                        .offset(x: originX, y: originY)
                                    
                                    // Hotspot Crosshair Marker
                                    if showHotspotMarker {
                                        let hx = originX + currentFrame.hotspot.x * scale
                                        let hy = originY + currentFrame.hotspot.y * scale
                                        
                                        Circle()
                                            .stroke(Color.red, lineWidth: 2)
                                            .background(Circle().fill(Color.red.opacity(0.3)))
                                            .frame(width: 14, height: 14)
                                            .position(x: hx, y: hy)
                                        
                                        // Crosshair Lines
                                        Path { path in
                                            path.move(to: CGPoint(x: hx - 12, y: hy))
                                            path.addLine(to: CGPoint(x: hx + 12, y: hy))
                                            path.move(to: CGPoint(x: hx, y: hy - 12))
                                            path.addLine(to: CGPoint(x: hx, y: hy + 12))
                                        }
                                        .stroke(Color.red, lineWidth: 1.5)
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 220, height: 220)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
                    
                    // Control & Specs Panel
                    VStack(alignment: .leading, spacing: 14) {
                        Toggle(L10n.tr("show_hotspot_marker"), isOn: $showHotspotMarker)
                            .font(.subheadline)
                        
                        Divider()
                        
                        // Animation playback controls
                        if item.isAnimated && item.frames.count > 1 {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 12) {
                                    Button(action: togglePlayPause) {
                                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                            .frame(width: 24)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button(action: stepBackward) {
                                        Image(systemName: "backward.frame.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isPlaying)
                                    
                                    Button(action: stepForward) {
                                        Image(systemName: "forward.frame.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(isPlaying)
                                    
                                    Text(L10n.tr("frame_step_label", currentFrameIndex + 1, item.frames.count))
                                        .font(.subheadline)
                                        .monospacedDigit()
                                }
                                
                                HStack {
                                    Text(L10n.tr("playback_speed", speedMultiplier))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Slider(value: $speedMultiplier, in: 0.25...3.0, step: 0.25)
                                        .onChange(of: speedMultiplier) { _ in
                                            if isPlaying { restartAnimation() }
                                        }
                                }
                            }
                            
                            Divider()
                        }
                        
                        // Technical Specs Grid
                        VStack(alignment: .leading, spacing: 6) {
                            specRow(label: L10n.tr("spec_source_file"), value: item.sourceFileName)
                            specRow(label: L10n.tr("spec_cursor_size"), value: L10n.tr("spec_cursor_size_val", Int(item.size.width), Int(item.size.height)))
                            specRow(label: L10n.tr("spec_hotspot"), value: L10n.tr("spec_hotspot_val", Int(item.hotspot.x), Int(item.hotspot.y)))
                            if item.isAnimated {
                                specRow(label: L10n.tr("spec_frame_duration"), value: L10n.tr("spec_frame_duration_val", item.frameRate, Int(round(1.0 / max(0.001, item.frameRate)))))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Filmstrip (for animated cursors)
                if item.isAnimated && item.frames.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tr("filmstrip_title", item.frames.count))
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            HStack(spacing: 8) {
                                ForEach(0..<item.frames.count, id: \.self) { idx in
                                    let frame = item.frames[idx]
                                    VStack(spacing: 4) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(Color(NSColor.controlBackgroundColor))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 6)
                                                        .stroke(currentFrameIndex == idx ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: currentFrameIndex == idx ? 2 : 1)
                                                )
                                            
                                            Image(nsImage: frame.image)
                                                .interpolation(.none)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 28, height: 28)
                                        }
                                        
                                        Text("#\(idx + 1)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isPlaying = false
                                        stopAnimation()
                                        currentFrameIndex = idx
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Mapped macOS Identifiers
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("system_mappings_title"))
                        .font(.headline)
                    
                    FlowLayout(spacing: 6) {
                        ForEach(item.role.macIdentifiers, id: \.self) { ident in
                            Text(ident)
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                
                Divider()
                
                // Interactive Playground
                CursorPlaygroundView(item: item)
            }
            .padding(20)
        }
        .onAppear {
            currentFrameIndex = 0
            if isPlaying { restartAnimation() }
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: item.id) { _ in
            currentFrameIndex = 0
            if isPlaying { restartAnimation() }
        }
    }

    private var activeFrame: CursorFrame? {
        if item.isAnimated && !item.frames.isEmpty {
            return item.frames[currentFrameIndex % item.frames.count]
        }
        return item.frames.first
    }

    @ViewBuilder
    private var previewBackground: some View {
        switch backgroundMode {
        case .checkerboard:
            CheckerboardView()
        case .light:
            Color.white
        case .dark:
            Color(white: 0.12)
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: langManager.effectiveLanguageIsChinese ? 80 : 115, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
        }
    }

    private func togglePlayPause() {
        isPlaying.toggle()
        if isPlaying {
            restartAnimation()
        } else {
            stopAnimation()
        }
    }

    private func stepForward() {
        guard !item.frames.isEmpty else { return }
        currentFrameIndex = (currentFrameIndex + 1) % item.frames.count
    }

    private func stepBackward() {
        guard !item.frames.isEmpty else { return }
        currentFrameIndex = (currentFrameIndex - 1 + item.frames.count) % item.frames.count
    }

    private func restartAnimation() {
        stopAnimation()
        guard item.isAnimated, item.frames.count > 1 else { return }
        let interval = max(0.016, item.frameRate / speedMultiplier)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            if !item.frames.isEmpty {
                currentFrameIndex = (currentFrameIndex + 1) % item.frames.count
            }
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}

private struct CheckerboardView: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let squareSize: CGFloat = 12
                let cols = Int(ceil(size.width / squareSize))
                let rows = Int(ceil(size.height / squareSize))

                for r in 0..<rows {
                    for c in 0..<cols {
                        let isEven = (r + c) % 2 == 0
                        let rect = CGRect(
                            x: CGFloat(c) * squareSize,
                            y: CGFloat(r) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        let color = isEven ? Color(white: 0.93) : Color(white: 0.82)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
