//
//  ContentView.swift
//  EasyPhoto
//
//  主界面：全宽图片区 + 右侧悬浮 EXIF 面板
//
//  付费规则：浏览完全免费，幻灯片是 Pro 功能（$0.99 解锁）
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

    // 付费
    @ObservedObject private var pm = PurchaseManager.shared
    @State private var showingPaywall: Bool = false

    // EXIF 浮动面板
    @State private var isExifForcedOn: Bool = false
    @State private var isExifHoverOn: Bool = false
    @State private var exifDragOffset: CGSize = .zero
    @State private var exifDragLastOffset: CGSize = .zero
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
                        .onHover { handleEdgeHover($0) }
                }

                // ── 浮动 EXIF 面板 ─────────────────────
                if isExifVisible {
                    let panelW: CGFloat = 280
                    let panelH: CGFloat = min(540, geo.size.height - 40)

                    ExifPanel(metadata: metadata, imageURL: currentImageURL)
                        .frame(width: panelW, height: panelH)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.25), radius: 16, x: -2, y: 2)
                        .position(
                            x: geo.size.width - panelW / 2 - 10 + exifDragOffset.width,
                            y: geo.size.height / 2 + exifDragOffset.height
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
                        .onHover { handlePanelHover($0) }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .trailing)),
                            removal: .opacity
                        ))
                }

                // ── 付费墙 ─────────────────────────────
                if showingPaywall {
                    PaywallView(onDismiss: { showingPaywall = false })
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isExifVisible)
            .animation(.easeInOut(duration: 0.2), value: showingPaywall)
        }
        .frame(minWidth: 800, minHeight: 500)
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
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
        .background(
            // NSViewRepresentable：updateNSView 在每次 SwiftUI 渲染后更新回调，
            // 确保闭包始终捕获最新状态；NSEvent monitor 不依赖 first responder
            KeyboardHandlerBridge(
                onLeft:      { navigateImage(direction: -1) },
                onRight:     { navigateImage(direction:  1) },
                onExif: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExifForcedOn.toggle()
                        if isExifForcedOn { hideTaskBox.cancel() }
                    }
                },
                onSlideshow: { toggleSlideshow() }
            )
        )
    }

    // MARK: - 悬停

    private func handleEdgeHover(_ entering: Bool) {
        if entering {
            hideTaskBox.cancel()
            withAnimation(.easeInOut(duration: 0.2)) { isExifHoverOn = true }
        } else {
            scheduleHide()
        }
    }

    private func handlePanelHover(_ entering: Bool) {
        if entering { hideTaskBox.cancel() } else { scheduleHide() }
    }

    private func scheduleHide() {
        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) { isExifHoverOn = false }
        }
        hideTaskBox.set(task)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: task)
    }

    // MARK: - 拖拽

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                loadImage(from: url)
                loadFolderImages(from: url)
            }
        }
        return true
    }

    // MARK: - 图片加载（无任何限制）

    private func loadImage(from url: URL) {
        let resolved = url.resolvingSymlinksInPath()
        _ = resolved.startAccessingSecurityScopedResource()
        guard let image = NSImage(contentsOf: resolved) else { return }
        currentImage = image
        currentImageURL = resolved
        metadata = ExifParser.parse(from: resolved)
        if let index = folderImages.firstIndex(where: { $0.resolvingSymlinksInPath() == resolved }) {
            currentIndex = index
        }
    }

    // MARK: - 文件夹（加载全部，无截断）

    private static let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif",
                                              "gif", "bmp", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng"])

    private func loadFolderImages(from url: URL) {
        let resolved = url.resolvingSymlinksInPath()
        let folderURL = resolved.deletingLastPathComponent()
        _ = folderURL.startAccessingSecurityScopedResource()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles]
        ) else { return }

        folderImages = contents
            .filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        if let index = folderImages.firstIndex(where: { $0.resolvingSymlinksInPath() == resolved }) {
            currentIndex = index
        }
    }

    private func openFolder(_ folderURL: URL) {
        let resolved = folderURL.resolvingSymlinksInPath()
        _ = resolved.startAccessingSecurityScopedResource()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: resolved, includingPropertiesForKeys: [.contentTypeKey], options: [.skipsHiddenFiles]
        ) else { return }

        folderImages = contents
            .filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        if let first = folderImages.first {
            currentIndex = 0
            loadImage(from: first)
        }
    }

    // MARK: - 图片导航

    private func navigateImage(direction: Int) {
        guard !folderImages.isEmpty else { return }
        let newIndex = currentIndex + direction
        guard newIndex >= 0 && newIndex < folderImages.count else { return }
        currentIndex = newIndex
        loadImage(from: folderImages[currentIndex])
    }

    // MARK: - 幻灯片（Pro 功能，未付费弹付费墙）

    private func toggleSlideshow() {
        if slideshowActive {
            stopSlideshow()
            return
        }
        guard pm.isUnlocked else {
            withAnimation(.easeInOut(duration: 0.2)) { showingPaywall = true }
            return
        }
        startSlideshow()
    }

    private func startSlideshow() {
        guard !folderImages.isEmpty else { return }
        slideshowActive = true
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            DispatchQueue.main.async {
                let next = (currentIndex + 1) % folderImages.count
                currentIndex = next
                loadImage(from: folderImages[next])
            }
        }
    }

    private func stopSlideshow() {
        slideshowActive = false
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }
}

// MARK: - HideTaskBox

class HideTaskBox {
    private var task: DispatchWorkItem?
    func set(_ newTask: DispatchWorkItem) { task?.cancel(); task = newTask }
    func cancel() { task?.cancel(); task = nil }
}

// MARK: - 键盘监听（NSViewRepresentable，updateNSView 每次渲染后更新回调）

struct KeyboardHandlerBridge: NSViewRepresentable {
    var onLeft:      () -> Void
    var onRight:     () -> Void
    var onExif:      () -> Void
    var onSlideshow: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyboardListenerView()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? KeyboardListenerView else { return }
        view.onLeft      = onLeft
        view.onRight     = onRight
        view.onExif      = onExif
        view.onSlideshow = onSlideshow
        view.installMonitorIfNeeded()
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: ()) {
        (nsView as? KeyboardListenerView)?.removeMonitor()
    }
}

class KeyboardListenerView: NSView {
    var onLeft:      (() -> Void)?
    var onRight:     (() -> Void)?
    var onExif:      (() -> Void)?
    var onSlideshow: (() -> Void)?

    private var monitor: Any?

    func installMonitorIfNeeded() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            switch event.keyCode {
            case 123: self.onLeft?();      return nil
            case 124: self.onRight?();     return nil
            case 34:  self.onExif?();      return nil
            case 1:   self.onSlideshow?(); return nil
            default:  return event
            }
        }
    }

    func removeMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    deinit { removeMonitor() }
}

#Preview { ContentView() }
