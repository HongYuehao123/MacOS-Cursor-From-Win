import AppKit
import SwiftUI

public struct CursorPlaygroundView: View {
    @ObservedObject var item: CursorItem
    @State private var clickCount: Int = 0
    @State private var lastClickPoint: CGPoint? = nil

    public init(item: CursorItem) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("鼠标试用体验画板 (Playground)", systemImage: "cursorarrow.rays")
                    .font(.headline)
                Spacer()
                if clickCount > 0 {
                    Text("测试点击次数: \(clickCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ZStack {
                PlaygroundNSViewRepresentable(item: item, onClick: { point in
                    self.clickCount += 1
                    self.lastClickPoint = point
                })
                .frame(height: 140)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.5)
                )

                VStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("把鼠标移入此区域，即可即时体验【\(item.name)】的手感与点击对准度")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("点击此区域可测试准星对齐效果")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .allowsHitTesting(false)
            }
        }
    }
}

private struct PlaygroundNSViewRepresentable: NSViewRepresentable {
    let item: CursorItem
    let onClick: (CGPoint) -> Void

    func makeNSView(context: Context) -> PlaygroundContainerView {
        let view = PlaygroundContainerView()
        view.onClick = onClick
        view.updateCursor(with: item)
        return view
    }

    func updateNSView(_ nsView: PlaygroundContainerView, context: Context) {
        nsView.onClick = onClick
        nsView.updateCursor(with: item)
    }
}

private class PlaygroundContainerView: NSView {
    var onClick: ((CGPoint) -> Void)?
    private var currentItem: CursorItem?
    private var currentCursor: NSCursor?
    private var currentFrameIndex: Int = 0
    private var animTimer: Timer?
    private var isMouseInside: Bool = false
    private var trackingAreaRef: NSTrackingArea?

    private var ripplePoint: CGPoint?
    private var rippleRadius: CGFloat = 0
    private var rippleTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingAreaRef {
            removeTrackingArea(existing)
        }
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingAreaRef = trackingArea
    }

    func updateCursor(with item: CursorItem) {
        let itemChanged = (self.currentItem?.id != item.id)
        self.currentItem = item

        if itemChanged || currentCursor == nil {
            self.currentFrameIndex = 0
            refreshCurrentCursor()
        }

        if isMouseInside {
            startAnimationTimer()
            currentCursor?.set()
        } else {
            stopAnimationTimer()
        }
    }

    private func refreshCurrentCursor() {
        guard let item = currentItem, !item.frames.isEmpty else {
            self.currentCursor = .arrow
            window?.invalidateCursorRects(for: self)
            return
        }

        let frameIdx = currentFrameIndex % item.frames.count
        let frame = item.frames[frameIdx]
        self.currentCursor = NSCursor(image: frame.image, hotSpot: frame.hotspot)
        window?.invalidateCursorRects(for: self)
    }

    private func startAnimationTimer() {
        stopAnimationTimer()
        guard let item = currentItem, item.isAnimated, item.frames.count > 1 else { return }

        let interval = max(0.016, item.frameRate)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isMouseInside, let item = self.currentItem, !item.frames.isEmpty else { return }

            // Safeguard: verify mouse is still within bounds
            if let win = self.window {
                let mouseInWindow = win.mouseLocationOutsideOfEventStream
                let mouseInView = self.convert(mouseInWindow, from: nil)
                if !self.bounds.contains(mouseInView) {
                    self.isMouseInside = false
                    self.stopAnimationTimer()
                    return
                }
            }

            self.currentFrameIndex = (self.currentFrameIndex + 1) % item.frames.count
            let frame = item.frames[self.currentFrameIndex]
            let cursor = NSCursor(image: frame.image, hotSpot: frame.hotspot)
            self.currentCursor = cursor
            cursor.set()
        }
        self.animTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAnimationTimer() {
        animTimer?.invalidate()
        animTimer = nil
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isMouseInside = true
        startAnimationTimer()
        currentCursor?.set()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isMouseInside = false
        stopAnimationTimer()
        NSCursor.arrow.set()
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        if isMouseInside, let cursor = currentCursor {
            cursor.set()
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        if isMouseInside, let cursor = currentCursor {
            cursor.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    override func resetCursorRects() {
        if let cursor = currentCursor {
            addCursorRect(bounds, cursor: cursor)
        } else {
            super.resetCursorRects()
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            isMouseInside = false
            stopAnimationTimer()
            rippleTimer?.invalidate()
        }
    }

    deinit {
        stopAnimationTimer()
        rippleTimer?.invalidate()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        onClick?(point)
        triggerRipple(at: point)
    }

    private func triggerRipple(at point: CGPoint) {
        self.ripplePoint = point
        self.rippleRadius = 0
        rippleTimer?.invalidate()
        rippleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.rippleRadius += 4
            self.needsDisplay = true
            if self.rippleRadius > 50 {
                timer.invalidate()
                self.rippleTimer = nil
                self.ripplePoint = nil
                self.needsDisplay = true
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw subtle grid pattern
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.setStrokeColor(NSColor.separatorColor.withAlphaComponent(0.15).cgColor)
            ctx.setLineWidth(1.0)
            let gridSize: CGFloat = 20.0
            var x: CGFloat = 0
            while x < bounds.width {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: bounds.height))
                x += gridSize
            }
            var y: CGFloat = 0
            while y < bounds.height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: bounds.width, y: y))
                y += gridSize
            }
            ctx.strokePath()

            // Draw ripple effect if clicking
            if let point = ripplePoint, rippleRadius > 0 {
                let alpha = max(0.0, 1.0 - (rippleRadius / 50.0))
                ctx.setStrokeColor(NSColor.controlAccentColor.withAlphaComponent(alpha).cgColor)
                ctx.setLineWidth(2.0)
                ctx.strokeEllipse(in: CGRect(
                    x: point.x - rippleRadius,
                    y: point.y - rippleRadius,
                    width: rippleRadius * 2,
                    height: rippleRadius * 2
                ))
            }
        }
    }
}
