//
//  ContentView.swift
//  EasyPhoto
//
//  主界面：左侧图片 + 右侧 EXIF 信息
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var loc: LocalizationManager
    @State private var currentImage: NSImage?
    @State private var metadata: ImageMetadata?
    @State private var isDragging = false
    @State private var currentImageURL: URL?
    @State private var folderImages: [URL] = []
    @State private var currentIndex: Int = 0
    @State private var showExif: Bool = true
    @State private var slideshowActive: Bool = false
    @State private var slideshowTimer: Timer?
    
    var body: some View {
        HSplitView {
            // 左侧：图片显示区域
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                if let image = currentImage {
                    ImageViewer(image: image, onNavigate: { direction in
                        navigateImage(direction: direction)
                    })
                } else {
                    // 拖拽提示
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary)

                        Text(loc.s(.dropHint))
                            .font(.title2)
                            .foregroundColor(.secondary)

                        Text(loc.s(.formatHint))
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))

                        Text(loc.s(.shortcutHint))
                            .font(.caption2)
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.top, 8)
                    }
                }
                
                // 幻灯片播放指示
                if slideshowActive {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(loc.s(.slideshowPlaying)) (\(loc.s(.slideshowStop)))")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .padding(12)
                        }
                        Spacer()
                    }
                }

                // 拖拽高亮效果
                if isDragging {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .background(Color.accentColor.opacity(0.1))
                        .padding(8)
                }
            }
            .frame(minWidth: 500, minHeight: 400)
            .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                handleDrop(providers: providers)
            }
            
            // 右侧：EXIF 信息面板
            if showExif {
                ExifPanel(metadata: metadata, imageURL: currentImageURL)
                    .frame(width: 280)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            setupKeyboardShortcuts()
        }
        .background(KeyboardEventHandler(
            onLeftArrow: { navigateImage(direction: -1) },
            onRightArrow: { navigateImage(direction: 1) },
            onToggleExif: { showExif.toggle() },
            onToggleSlideshow: { toggleSlideshow() }
        ))
    }
    
    // MARK: - 拖拽处理
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                return
            }
            
            DispatchQueue.main.async {
                loadImage(from: url)
                loadFolderImages(from: url)
            }
        }
        
        return true
    }
    
    // MARK: - 图片加载
    
    private func loadImage(from url: URL) {
        guard let image = NSImage(contentsOf: url) else {
            print("无法加载图片: \(url.path)")
            return
        }
        
        currentImage = image
        currentImageURL = url
        metadata = ExifParser.parse(from: url)
        
        // 更新当前索引
        if let index = folderImages.firstIndex(of: url) {
            currentIndex = index
        }
    }
    
    // MARK: - 文件夹图片列表
    
    private func loadFolderImages(from url: URL) {
        let folderURL = url.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentTypeKey],
                options: [.skipsHiddenFiles]
            )
            
            // 过滤图片文件
            let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng"]
            
            folderImages = contents.filter { fileURL in
                imageExtensions.contains(fileURL.pathExtension.lowercased())
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            
            // 设置当前索引
            if let index = folderImages.firstIndex(of: url) {
                currentIndex = index
            }
            
        } catch {
            print("无法读取文件夹: \(error)")
        }
    }
    
    // MARK: - 图片导航
    
    private func navigateImage(direction: Int) {
        guard !folderImages.isEmpty else { return }
        
        let newIndex = currentIndex + direction
        
        if newIndex >= 0 && newIndex < folderImages.count {
            currentIndex = newIndex
            loadImage(from: folderImages[currentIndex])
        }
    }
    
    // MARK: - 幻灯片

    private func toggleSlideshow() {
        if slideshowActive {
            stopSlideshow()
        } else {
            startSlideshow()
        }
    }

    private func startSlideshow() {
        guard !folderImages.isEmpty else { return }
        slideshowActive = true
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            DispatchQueue.main.async {
                let nextIndex = currentIndex + 1
                if nextIndex < folderImages.count {
                    currentIndex = nextIndex
                    loadImage(from: folderImages[currentIndex])
                } else {
                    // 播放到最后一张，循环回第一张
                    currentIndex = 0
                    loadImage(from: folderImages[currentIndex])
                }
            }
        }
    }

    private func stopSlideshow() {
        slideshowActive = false
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }

    private func setupKeyboardShortcuts() {
        // 键盘事件在 KeyboardEventHandler 中处理
    }
}

// MARK: - 键盘事件处理

struct KeyboardEventHandler: NSViewRepresentable {
    var onLeftArrow: () -> Void
    var onRightArrow: () -> Void
    var onToggleExif: () -> Void
    var onToggleSlideshow: () -> Void

    func makeNSView(context: Context) -> KeyboardView {
        let view = KeyboardView()
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onToggleExif = onToggleExif
        view.onToggleSlideshow = onToggleSlideshow
        return view
    }

    func updateNSView(_ nsView: KeyboardView, context: Context) {
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
        nsView.onToggleExif = onToggleExif
        nsView.onToggleSlideshow = onToggleSlideshow
    }
}

class KeyboardView: NSView {
    var onLeftArrow: (() -> Void)?
    var onRightArrow: (() -> Void)?
    var onToggleExif: (() -> Void)?
    var onToggleSlideshow: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: // 左箭头
            onLeftArrow?()
        case 124: // 右箭头
            onRightArrow?()
        case 34: // I 键
            onToggleExif?()
        case 1: // S 键
            onToggleSlideshow?()
        default:
            super.keyDown(with: event)
        }
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}

#Preview {
    ContentView()
}
