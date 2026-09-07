import AppKit
import SwiftUI

public struct CursorItemView: View {
    @ObservedObject var item: CursorItem
    let isSelected: Bool
    @State private var currentFrameIndex: Int = 0
    @State private var timer: Timer?

    public init(item: CursorItem, isSelected: Bool) {
        self.item = item
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Cursor Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 52, height: 52)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )

                if let currentImage = displayImage {
                    Image(nsImage: currentImage)
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    if item.isAnimated {
                        Text("\(item.frames.count)帧动画")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    } else {
                        Text("静态")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }

                Text(item.role.localizedName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("热点: (\(Int(item.hotspot.x)), \(Int(item.hotspot.y)))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))

                    Text("尺寸: \(Int(item.size.width))×\(Int(item.size.height))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        )
        .contentShape(Rectangle())
        .onAppear {
            startAnimationIfNeeded()
        }
        .onDisappear {
            stopAnimation()
        }
    }

    private var displayImage: NSImage? {
        if item.isAnimated && !item.frames.isEmpty {
            let index = currentFrameIndex % item.frames.count
            return item.frames[index].image
        }
        return item.previewImage
    }

    private func startAnimationIfNeeded() {
        guard item.isAnimated, item.frames.count > 1 else { return }
        stopAnimation()
        let interval = max(0.033, item.frameRate)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            currentFrameIndex = (currentFrameIndex + 1) % item.frames.count
        }
    }

    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }
}
