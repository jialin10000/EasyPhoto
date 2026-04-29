//
//  ImageViewer.swift
//  EasyPhoto
//
//  图片显示视图 - 支持缩放和拖动
//

import SwiftUI

struct ImageViewer: View {
    let image: NSImage
    var onNavigate: ((Int) -> Void)?  // -1 = 上一张, 1 = 下一张

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // ── 图片层：只挂缩放手势，不挂拖拽 ──
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, 0.5), 10.0)
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 0.8 {
                                    withAnimation(.spring(response: 0.3)) {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                }
                            }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── 手势层：根据缩放状态切换，避免冲突 ──
                if scale <= 1.0 {
                    // 未放大：点击左/右半区导航，双击放大
                    HStack(spacing: 0) {
                        // 左半区 → 上一张
                        Color.white.opacity(0.001)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture(count: 2).onEnded {
                                    withAnimation(.spring(response: 0.3)) {
                                        scale = 2.0
                                        lastScale = 2.0
                                    }
                                }
                                .exclusively(before:
                                    TapGesture(count: 1).onEnded {
                                        onNavigate?(-1)
                                    }
                                )
                            )

                        // 右半区 → 下一张
                        Color.white.opacity(0.001)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                            .gesture(
                                TapGesture(count: 2).onEnded {
                                    withAnimation(.spring(response: 0.3)) {
                                        scale = 2.0
                                        lastScale = 2.0
                                    }
                                }
                                .exclusively(before:
                                    TapGesture(count: 1).onEnded {
                                        onNavigate?(1)
                                    }
                                )
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // 放大时：拖拽平移 + 双击复原
                    Color.white.opacity(0.001)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3)) {
                                scale = 1.0
                                lastScale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onChange(of: image) { _, _ in
            // 切换图片时重置缩放和位置
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.0
                lastScale = 1.0
                offset = .zero
                lastOffset = .zero
            }
        }
    }
}

#Preview {
    ImageViewer(image: NSImage(systemSymbolName: "photo", accessibilityDescription: nil)!)
        .frame(width: 600, height: 400)
}
