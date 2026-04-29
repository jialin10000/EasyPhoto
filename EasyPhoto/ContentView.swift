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

    // 键盘监听
    @State private var keyMonitorBox = KeyMonitorBox()

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
                    let panelH: CGFloat = min(540, geo.size.height - 40)

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
                            if paywallFromSlideshow { startSlideshow() }
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
        .onAppear {
            slideshowIntervalSeconds = validatedSlideshowInterval(from: slideshowIntervalSeconds)

            keyMonitorBox.setup(
                onLeft:      { navigateImage(direction: -1, userInitiated: true) },
                onRight:     { navigateImage(direction:  1, userInitiated: true) },
                onExif: {
                    let newValue = !isExifForcedOn
                    withAnimation(.easeInOut(duration: 0.2)) { isExifForcedOn = newValue }
                    if newValue {
                        exifHideTaskBox.cancel()
                    } else {
                        scheduleExifHideIfNeeded()
                    }
                },
                onSlideshow: { toggleSlideshow() },
                onFullscreen: { toggleFullscreen() }
            )
        }
        .onDisappear {
            keyMonitorBox.teardown()
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

        if let index = folderImages.firstIndex(of: url) {
            currentIndex = index
        } else if let index = folderImages.firstIndex(where: { $0.path == url.path }) {
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

// MARK: - 键盘监听（全局，不依赖 first responder）

class KeyMonitorBox {
    private var monitor: Any?

    func setup(
        onLeft:      @escaping () -> Void,
        onRight:     @escaping () -> Void,
        onExif:      @escaping () -> Void,
        onSlideshow: @escaping () -> Void,
        onFullscreen:@escaping () -> Void
    ) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 123: onLeft();      return nil
            case 124: onRight();     return nil
            case 34:  onExif();      return nil
            case 1:   onSlideshow(); return nil
            case 3:   onFullscreen(); return nil
            default:  return event
            }
        }
    }

    func teardown() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    deinit { teardown() }
}

#Preview { ContentView() }
