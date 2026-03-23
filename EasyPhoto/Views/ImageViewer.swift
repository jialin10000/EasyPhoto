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
                    .gesture(
                        // 缩放手势
                        MagnificationGesture()
                            .onChanged { value in
                                let newScale = lastScale * value
                                scale = min(max(newScale, 0.5), 10.0)
                            }
                            .onEnded { _ in
                                lastScale = scale

                                // 如果缩放太小，恢复到 1.0
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
                    .gesture(
                        // 拖动手势（仅在放大时生效）
                        DragGesture()
                            .onChanged { value in
                                if scale > 1.0 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // 点击左/右半区切换图片（仅在未放大时）
                if scale <= 1.0 {
                    HStack(spacing: 0) {
                        // 左半区 → 上一张
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.3)) {
                                    scale = 2.0
                                }
                            }
                            .onTapGesture(count: 1) {
                                onNavigate?(-1)
                            }

                        // 右半区 → 下一张
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.3)) {
                                    scale = 2.0
                                }
                            }
                            .onTapGesture(count: 1) {
                                onNavigate?(1)
                            }
                    }
                } else {
                    // 放大时，双击恢复原始大小
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3)) {
                                scale = 1.0
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
