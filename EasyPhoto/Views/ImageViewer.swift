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
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 点击左/右半区切换图片（仅在未放大时）
                // 注意：macOS 上 Color.clear 不接受点击，用极低不透明度的 Color
                if scale <= 1.0 {
                    HStack(spacing: 0) {
                        // 左半区 → 上一张（单击导航，双击放大）
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

                        // 右半区 → 下一张（单击导航，双击放大）
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
                    // 放大时，双击恢复原始大小
                    Color.white.opacity(0.001)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
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
            // 触控板捏合缩放（simultaneousGesture 不影响左右点击）
            .simultaneousGesture(
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
            // 拖动平移（minimumDistance 5pt 避免误触；仅放大时生效）
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        guard scale > 1.0 else { return }
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        if scale > 1.0 { lastOffset = offset }
                    }
            )
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
