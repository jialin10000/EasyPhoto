//
//  ContentView.swift
//  EasyPhoto
//
//  主界面：全宽图片区 + 右侧悬浮 EXIF 面板
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
    @State private var slideshowActive: Bool = false
    @State private var slideshowTimer: Timer?

    // 付费墙
    @ObservedObject private var pm = PurchaseManager.shared
    @State private var showingPaywall: Bool = false

    // EXIF 浮动面板状态
    @State private var isExifForcedOn: Bool = false    // I 键强制显示/隐藏
    @State private var isExifHoverOn: Bool = false     // 鼠标悬停触发
    @State private var exifDragOffset: CGSize = .zero  // 用户拖动的偏移
    @State private var exifDragLastOffset: CGSize = .zero
    private var hoverHideTask: DispatchWorkItem? = nil  // not @State, managed manually

    // 鼠标离开后延迟隐藏的 work item，用 class wrapper 绕过 @State 限制
    @State private var hideTaskBox = HideTaskBox()

    var isExifVisible: Bool { isExifForcedOn || isExifHoverOn }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── 背景 ──────────────────────────────
                Color(NSColor.windowBackgroundColor)

                // ── 图片区（全宽） ─────────────────────
                if let image = currentImage {
                    ImageViewer(image: image, onNavigate: { direction in
                        navigateImage(direction: direction)
                    })
                } else {
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

                // ── 幻灯片指示 ─────────────────────────
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

                // ── 拖拽高亮 ────────────────────────────
                if isDragging {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 3)
                        .background(Color.accentColor.opacity(0.1))
                        .padding(8)
                }

                // ── 右侧边缘触发区（不可见，20px 宽） ──
                HStack(spacing: 0) {
                    Spacer()
                    Color.clear
                        .frame(width: 20)
                        .contentShape(Rectangle())
                        .onHover { entering in
                            handleEdgeHover(entering)
                        }
                }

                // ── 浮动 EXIF 面板 ─────────────────────
                if isExifVisible {
                    let panelW: CGFloat = 280
                    let panelH: CGFloat = min(540, geo.size.height - 40)
                    let defaultX = geo.size.width - panelW / 2 - 10
                    let defaultY = geo.size.height / 2

                    ExifPanel(metadata: metadata, imageURL: currentImageURL)
                        .frame(width: panelW, height: panelH)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.25), radius: 16, x: -2, y: 2)
                        .position(
                            x: defaultX + exifDragOffset.width,
                            y: defaultY + exifDragOffset.height
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    exifDragOffset = CGSize(
                                        width: exifDragLastOffset.width + value.translation.width,
                                        height: exifDragLastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    exifDragLastOffset = exifDragOffset
                                }
                        )
                        .onHover { entering in
                            handlePanelHover(entering)
                        }
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .trailing)),
                                removal: .opacity
                            )
                        )
                }

                // ── 付费墙 ─────────────────────────────
                if showingPaywall {
                    PaywallView(onDismiss: { showingPaywall = false })
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isExifVisible)
        }
        .frame(minWidth: 800, minHeight: 500)
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
        .onAppear {
            setupKeyboardShortcuts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImageFile)) { notification in
            if let url = notification.object as? URL {
                loadImage(from: url)
                loadFolderImages(from: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImageFolder)) { notification in
            if let folderURL = notification.object as? URL {
                openFolder(folderURL)
            }
        }
        .background(KeyboardEventHandler(
            onLeftArrow: { navigateImage(direction: -1) },
            onRightArrow: { navigateImage(direction: 1) },
            onToggleExif: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExifForcedOn.toggle()
                    // 强制开启时，取消 hover 计时器
                    if isExifForcedOn { hideTaskBox.cancel() }
                }
            },
            onToggleSlideshow: { toggleSlideshow() }
        ))
    }

    // MARK: - 悬停逻辑

    private func handleEdgeHover(_ entering: Bool) {
        if entering {
            hideTaskBox.cancel()
            withAnimation(.easeInOut(duration: 0.2)) {
                isExifHoverOn = true
            }
        } else {
            scheduleHide()
        }
    }

    private func handlePanelHover(_ entering: Bool) {
        if entering {
            hideTaskBox.cancel()
        } else {
            scheduleHide()
        }
    }

    private func scheduleHide() {
        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExifHoverOn = false
            }
        }
        hideTaskBox.set(task)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
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
        // 检查免费额度
        guard pm.recordView() else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingPaywall = true
            }
            return
        }

        guard let image = NSImage(contentsOf: url) else {
            print("无法加载图片: \(url.path)")
            return
        }

        currentImage = image
        currentImageURL = url
        metadata = ExifParser.parse(from: url)

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

            let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng"]

            folderImages = contents.filter { fileURL in
                imageExtensions.contains(fileURL.pathExtension.lowercased())
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

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

    // MARK: - 打开文件夹

    private func openFolder(_ folderURL: URL) {
        let fileManager = FileManager.default
        let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif", "gif", "bmp", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng"]

        do {
            let contents = try fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentTypeKey],
                options: [.skipsHiddenFiles]
            )

            folderImages = contents.filter { fileURL in
                imageExtensions.contains(fileURL.pathExtension.lowercased())
            }.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

            if let first = folderImages.first {
                currentIndex = 0
                loadImage(from: first)
            }
        } catch {
            print("无法读取文件夹: \(error)")
        }
    }

    private func setupKeyboardShortcuts() {
        // 键盘事件在 KeyboardEventHandler 中处理
    }
}

// MARK: - 延迟隐藏任务容器（绕过 @State 不能持有 DispatchWorkItem 的限制）

class HideTaskBox {
    private var task: DispatchWorkItem?

    func set(_ newTask: DispatchWorkItem) {
        task?.cancel()
        task = newTask
    }

    func cancel() {
        task?.cancel()
        task = nil
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
