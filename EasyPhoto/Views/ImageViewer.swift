//
//  ImageViewer.swift
//  EasyPhoto
//
//  图片显示视图 - 支持缩放和拖动
//

import SwiftUI

struct ImageViewer: View {
    let image: NSImage
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    // 双击恢复原始大小
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation(.spring(response: 0.3)) {
                                if scale != 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                } else {
                                    scale = 2.0
                                }
                            }
                        }
                )
                .gesture(
                    // 拖动手势
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
