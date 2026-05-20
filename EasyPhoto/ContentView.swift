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
import PDFKit

struct ContentView: View {
    @EnvironmentObject var loc: LocalizationManager
    @AppStorage("slideshowIntervalSeconds") private var slideshowIntervalSeconds: Int = 3
    @State private var currentImage: NSImage?
    @State private var metadata: ImageMetadata?
    @State private var isDragging = false
    @State private var currentImageURL: URL?
    @State private var folderImages: [URL] = []
    @State private var currentIndex: Int = 0
    @State private var slideshowActive: Bool = false
    @State private var slideshowTimer: Timer?
    @State private var showSlideshowHint: Bool = false
    @State private var showImageCountHint: Bool = false
    @State private var slideshowHintTaskBox = HideTaskBox()
    @State private var imageCountHintTaskBox = HideTaskBox()

    // 付费
    @ObservedObject private var pm = PurchaseManager.shared
    @State private var showingPaywall: Bool = false
    @State private var paywallFromSlideshow: Bool = false
    @State private var showUnlockBanner: Bool = false


    // EXIF 浮动面板
    @State private var isExifForcedOn: Bool = false
    @State private var isPointerInExifEdge: Bool = false
    @State private var isPointerInExifPanel: Bool = false
    @State private var isExifHoverVisible: Bool = false
    @State private var exifHideTaskBox = HideTaskBox()
    @State private var exifDragOffset: CGSize = .zero
    @State private var exifDragLastOffset: CGSize = .zero

    var isExifVisible: Bool { isExifForcedOn || isExifHoverVisible }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── 背景 ──────────────────────────────
                Color(NSColor.windowBackgroundColor)

                // ── 图片区（全宽） ─────────────────────
                if let image = currentImage {
                    ImageViewer(image: image, onNavigate: { direction in
                        navigateImage(direction: direction, userInitiated: true)
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
                if showSlideshowHint && !slideshowActive {
                    VStack {
                        HStack {
                            Spacer()
                            Text(loc.s(.slideshowStartHint))
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

                // ── 解锁成功 banner ──────────────────────
                if showUnlockBanner {
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text(loc.s(.unlockSuccessMessage))
                                .font(.subheadline.bold())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .padding(.top, 16)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
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
                    TrackingHoverView(
                        onEntered: { handleEdgeHover(true) },
                        onExited: { handleEdgeHover(false) }
                    )
                        .frame(width: 36)
                        .contentShape(Rectangle())
                }

                // ── 浮动 EXIF 面板 ─────────────────────
                if isExifVisible {
                    let panelW: CGFloat = 280
                    // 有 GPS 地图时面板更高，让地图完整显示
                    let basePanelH: CGFloat = metadata?.hasGPS == true ? 720 : 540
                    let panelH: CGFloat = min(basePanelH, geo.size.height - 40)

                    ExifPanel(metadata: metadata, imageURL: currentImageURL)
                        .overlay(
                            TrackingHoverView(
                                onEntered: { handlePanelHover(true) },
                                onExited: { handlePanelHover(false) }
                            )
                        )
                        .frame(width: panelW, height: panelH)
                        .background(.ultraThinMaterial.opacity(0.42))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.20), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.25), radius: 16, x: -2, y: 2)
                        .position(
                            x: geo.size.width - panelW / 2 - 10 + exifDragOffset.width,
                            y: geo.size.height / 2 + exifDragOffset.height
                        )
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 10)
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
                        .transition(.opacity)
                }

                // ── 图片计数提示 ────────────────────────
                if showImageCountHint && !folderImages.isEmpty && !slideshowActive {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("[\(currentIndex + 1)/\(folderImages.count)] \(currentImageURL?.lastPathComponent ?? "")")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(6)
                                .padding(8)
                        }
                    }
                }

                // ── 付费墙 ─────────────────────────────
                if showingPaywall {
                    PaywallView(
                        onDismiss: { showingPaywall = false },
                        onPurchased: {
                            showingPaywall = false
                            withAnimation(.easeInOut(duration: 0.3)) { showUnlockBanner = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeInOut(duration: 0.3)) { showUnlockBanner = false }
                            }
                            if !folderImages.isEmpty { startSlideshow() }
                        }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showingPaywall)
        }
        .frame(minWidth: 800, minHeight: 500)
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImageFile)) { notification in
            if let url = notification.object as? URL {
                loadImage(from: url, showCountHint: true)
                loadFolderImages(from: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openImageFolder)) { notification in
            if let folderURL = notification.object as? URL {
                openFolder(folderURL)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPaywall)) { _ in
            guard !pm.isUnlocked else { return }
            paywallFromSlideshow = false
            withAnimation(.easeInOut(duration: 0.2)) { showingPaywall = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .printCurrentImage)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { printCurrentImage() }
        }
        .background(
            KeyCaptureView(
                onLeft:      { navigateImage(direction: -1, userInitiated: true) },
                onRight:     { navigateImage(direction:  1, userInitiated: true) },
                onSlideshow: { toggleSlideshow() },
                onExif: {
                    let newValue = !isExifForcedOn
                    withAnimation(.easeInOut(duration: 0.2)) { isExifForcedOn = newValue }
                    if newValue { exifHideTaskBox.cancel() } else { scheduleExifHideIfNeeded() }
                },
                onFullscreen: { toggleFullscreen() }
            )
            .frame(width: 0, height: 0)
        )
        .onAppear {
            slideshowIntervalSeconds = validatedSlideshowInterval(from: slideshowIntervalSeconds)
        }
        .onDisappear {
            stopSlideshow()
        }
    }

    // MARK: - 悬停

    private func handleEdgeHover(_ entering: Bool) {
        if entering {
            isPointerInExifEdge = true
            showExifFromHover()
        } else {
            isPointerInExifEdge = false
            scheduleExifHideIfNeeded()
        }
    }

    private func handlePanelHover(_ entering: Bool) {
        if entering {
            isPointerInExifPanel = true
            showExifFromHover()
        } else {
            isPointerInExifPanel = false
            scheduleExifHideIfNeeded()
        }
    }

    private func showExifFromHover() {
        exifHideTaskBox.cancel()
        if !isExifHoverVisible {
            withAnimation(.easeInOut(duration: 0.12)) { isExifHoverVisible = true }
        }
    }

    private func scheduleExifHideIfNeeded() {
        let task = DispatchWorkItem {
            if !isPointerInExifEdge && !isPointerInExifPanel && !isExifForcedOn {
                isExifHoverVisible = false
            }
        }
        exifHideTaskBox.set(task)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: task)
    }

    // MARK: - 拖拽

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            DispatchQueue.main.async {
                loadImage(from: url, showCountHint: true)
                loadFolderImages(from: url)
            }
        }
        return true
    }

    // MARK: - 图片加载（无任何限制）

    private func loadImage(from url: URL, showCountHint: Bool = false) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }

        guard let image = NSImage(contentsOf: url) else { return }
        currentImage = image
        currentImageURL = url
        metadata = ExifParser.parse(from: url)
        // 先精确匹配，再用路径比较兜底（处理符号链接差异）
        if let index = folderImages.firstIndex(of: url) {
            currentIndex = index
        } else if let index = folderImages.firstIndex(where: { $0.path == url.path }) {
            currentIndex = index
        }

        if showCountHint {
            showSlideshowHintTemporarily()
            showImageCountHintTemporarily()
        }
    }

    // MARK: - 文件夹（加载全部，无截断）

    private static let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif",
                                              "gif", "bmp", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2", "dng"])

    private func loadFolderImages(from url: URL) {
        let folderURL = url.deletingLastPathComponent()
        folderImages = readImages(in: folderURL)

        if folderImages.isEmpty {
            // 沙盒限制，弹 NSOpenPanel 请求文件夹访问权限（iSeePro 方案）
            requestFolderAccess(containing: url, folderURL: folderURL)
            return
        }

        if let index = folderImages.firstIndex(of: url) {
            currentIndex = index
        } else if let index = folderImages.firstIndex(where: { $0.path == url.path }) {
            currentIndex = index
        }
    }

    private func requestFolderAccess(containing fileURL: URL, folderURL: URL) {
        let panel = NSOpenPanel()
        panel.message = "请授权访问照片所在文件夹，以便左右键浏览同目录图片"
        panel.prompt = "允许访问"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = folderURL
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let grantedURL = panel.url else { return }

        folderImages = readImages(in: grantedURL)
        let resolved = fileURL.resolvingSymlinksInPath()
        if let index = folderImages.firstIndex(of: fileURL) {
            currentIndex = index
        } else if let index = folderImages.firstIndex(where: {
            $0.resolvingSymlinksInPath() == resolved || $0.path == fileURL.path
        }) {
            currentIndex = index
        }
    }

    private func openFolder(_ folderURL: URL) {
        folderImages = readImages(in: folderURL)

        if let first = folderImages.first {
            currentIndex = 0
            loadImage(from: first, showCountHint: true)
        }
    }

    private func readImages(in folderURL: URL) -> [URL] {
        let scoped = folderURL.startAccessingSecurityScopedResource()
        defer {
            if scoped { folderURL.stopAccessingSecurityScopedResource() }
        }

        let fm = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        let primary = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: options)
        let fallback = try? fm.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: options)
        let contents = primary ?? fallback ?? []

        return contents
            .filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    // MARK: - 图片导航

    private func navigateImage(direction: Int, userInitiated: Bool) {
        guard !folderImages.isEmpty else { return }

        // 用当前显示的 URL 实时查位置，不依赖可能过时的 currentIndex
        let baseIndex: Int
        if let url = currentImageURL,
           let idx = folderImages.firstIndex(of: url)
            ?? folderImages.firstIndex(where: { $0.path == url.path }) {
            baseIndex = idx
        } else {
            baseIndex = currentIndex
        }

        let newIndex = baseIndex + direction
        guard newIndex >= 0 && newIndex < folderImages.count else { return }
        currentIndex = newIndex
        loadImage(from: folderImages[newIndex], showCountHint: userInitiated)
    }

    // MARK: - 幻灯片（Pro 功能，未付费弹付费墙）

    private func toggleSlideshow() {
        if slideshowActive {
            stopSlideshow(userInitiated: true)
            return
        }
        guard pm.isUnlocked else {
            paywallFromSlideshow = true
            withAnimation(.easeInOut(duration: 0.2)) { showingPaywall = true }
            return
        }
        startSlideshow()
    }

    private func startSlideshow() {
        guard !folderImages.isEmpty else { return }
        hideAllHints()
        slideshowActive = true
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(slideshowIntervalSeconds), repeats: true) { _ in
            DispatchQueue.main.async {
                let next = (currentIndex + 1) % folderImages.count
                currentIndex = next
                loadImage(from: folderImages[next], showCountHint: false)
            }
        }
    }

    private func stopSlideshow(userInitiated: Bool = false) {
        slideshowActive = false
        slideshowTimer?.invalidate()
        slideshowTimer = nil

        if userInitiated {
            showSlideshowHintTemporarily()
            showImageCountHintTemporarily()
        }
    }

    private func toggleFullscreen() {
        if let window = NSApp.keyWindow ?? NSApp.mainWindow ?? NSApp.windows.first {
            window.toggleFullScreen(nil)
        }
    }

    private func showSlideshowHintTemporarily() {
        slideshowHintTaskBox.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { showSlideshowHint = true }

        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) { showSlideshowHint = false }
        }
        slideshowHintTaskBox.set(task)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }

    private func showImageCountHintTemporarily() {
        guard !slideshowActive, !folderImages.isEmpty else { return }

        imageCountHintTaskBox.cancel()
        withAnimation(.easeInOut(duration: 0.2)) { showImageCountHint = true }

        let task = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) { showImageCountHint = false }
        }
        imageCountHintTaskBox.set(task)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: task)
    }

    private func hideAllHints() {
        slideshowHintTaskBox.cancel()
        imageCountHintTaskBox.cancel()

        withAnimation(.easeInOut(duration: 0.2)) {
            showSlideshowHint = false
            showImageCountHint = false
        }
    }

    private func validatedSlideshowInterval(from value: Int) -> Int {
        min(max(value, 1), 9)
    }

    // MARK: - 打印（PDFKit 方案，sandbox 需要 com.apple.security.print 权限）
    private func printCurrentImage() {
        guard let image = currentImage,
              let pdfPage = PDFPage(image: image) else { return }
        let doc = PDFDocument()
        doc.insert(pdfPage, at: 0)
        guard let op = doc.printOperation(for: .shared, scalingMode: .pageScaleToFit, autoRotate: true) else { return }
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        _ = op.run()
    }
}

private struct TrackingHoverView: NSViewRepresentable {
    let onEntered: () -> Void
    let onExited: () -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onEntered = onEntered
        view.onExited = onExited
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onEntered = onEntered
        nsView.onExited = onExited
        nsView.updateTrackingAreas()
    }
}

private final class TrackingNSView: NSView {
    var onEntered: (() -> Void)?
    var onExited: (() -> Void)?
    private var trackingAreaRef: NSTrackingArea?

    // 点击穿透：tracking 仍工作（hover 进入/退出），但鼠标点击直接传给下层
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeInKeyWindow,
            .inVisibleRect
        ]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onExited?()
    }
}

// MARK: - HideTaskBox

class HideTaskBox {
    private var task: DispatchWorkItem?
    func set(_ newTask: DispatchWorkItem) { task?.cancel(); task = newTask }
    func cancel() { task?.cancel(); task = nil }
}


// MARK: - 键盘捕获（NSViewRepresentable，兼容 macOS 26）

struct KeyCaptureView: NSViewRepresentable {
    var onLeft:      () -> Void
    var onRight:     () -> Void
    var onSlideshow: () -> Void
    var onExif:      () -> Void
    var onFullscreen:() -> Void

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let v = KeyCaptureNSView()
        v.onLeft = onLeft; v.onRight = onRight
        v.onSlideshow = onSlideshow; v.onExif = onExif; v.onFullscreen = onFullscreen
        return v
    }

    func updateNSView(_ v: KeyCaptureNSView, context: Context) {
        v.onLeft = onLeft; v.onRight = onRight
        v.onSlideshow = onSlideshow; v.onExif = onExif; v.onFullscreen = onFullscreen
        DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
    }
}

class KeyCaptureNSView: NSView {
    var onLeft:      (() -> Void)?
    var onRight:     (() -> Void)?
    var onSlideshow: (() -> Void)?
    var onExif:      (() -> Void)?
    var onFullscreen:(() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 窗口每次变为 key window 时重新抢占 first responder
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowBecameKey),
            name: NSWindow.didBecomeKeyNotification, object: window
        )
        DispatchQueue.main.async { self.window?.makeFirstResponder(self) }
    }

    @objc private func windowBecameKey() {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123: onLeft?()
        case 124: onRight?()
        case 1:   onSlideshow?()
        case 34:  onExif?()
        case 3:   onFullscreen?()
        default:  super.keyDown(with: event)
        }
    }
}

#Preview { ContentView() }
