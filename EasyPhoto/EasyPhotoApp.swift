//
//  EasyPhotoApp.swift
//  EasyPhoto
//
//  轻量级 Mac 看图软件 - 为摄影玩家打造
//

import SwiftUI
import UniformTypeIdentifiers

@main
struct EasyPhotoApp: App {
    @ObservedObject var loc = LocalizationManager.shared
    @AppStorage("slideshowIntervalSeconds") private var slideshowIntervalSeconds: Int = 3
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(loc)
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: .openImageFile,
                        object: url
                    )
                }
        }
        .handlesExternalEvents(matching: ["*"])
        .windowStyle(.automatic)
        .commands {
            // File > Open 菜单
            CommandGroup(replacing: .newItem) {
                Button(loc.s(.menuOpenFile)) {
                    openFilePanel()
                }
                .keyboardShortcut("o", modifiers: .command)

                Button(loc.s(.menuOpenFolder)) {
                    openFolderPanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            // 语言菜单
            CommandMenu(loc.s(.menuLanguage)) {
                ForEach(LocalizationManager.Language.allCases, id: \.rawValue) { lang in
                    Button {
                        guard loc.currentLanguage != lang else { return }
                        loc.setLanguageByUser(lang)
                        showLanguageChangeAlert(lang)
                    } label: {
                        HStack {
                            Text(lang.displayName(in: loc.currentLanguage))
                            if loc.currentLanguage == lang {
                                Text("✓")
                            }
                        }
                    }
                    .keyboardShortcut(lang == .chinese ? "1" : "2", modifiers: [.command, .shift])
                }
            }

            CommandMenu(loc.s(.menuSlideshow)) {
                Button(loc.s(.menuSlideshowInterval)) {
                    openSlideshowIntervalPanel()
                }
            }

            // Help 菜单
            CommandGroup(replacing: .help) {
                Button(loc.s(.menuHelp)) {
                    OpenHelpWindowHelper.shared.open()
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }

        // Help 窗口
        Window(loc.s(.helpTitle), id: "help") {
            HelpView()
        }
        .windowResizability(.contentSize)
    }

    private func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = imageContentTypes()

        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: .openImageFile, object: url)
        }
    }

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: .openImageFolder, object: url)
        }
    }

    private func imageContentTypes() -> [UTType] {
        [.jpeg, .png, .heic, .heif, .tiff, .gif, .bmp, .rawImage]
    }

    private func openSlideshowIntervalPanel() {
        let alert = NSAlert()
        alert.messageText = loc.s(.menuSlideshowInterval)
        alert.informativeText = "\(loc.s(.slideshowInterval)): 1-9 \(loc.s(.slideshowSeconds))"
        alert.alertStyle = .informational
        alert.addButton(withTitle: loc.s(.dialogConfirm))
        alert.addButton(withTitle: loc.s(.dialogCancel))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 120, height: 24))
        textField.stringValue = String(min(max(slideshowIntervalSeconds, 1), 9))
        textField.alignment = .right
        alert.accessoryView = textField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let parsed = Int(textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? slideshowIntervalSeconds
        slideshowIntervalSeconds = min(max(parsed, 1), 9)
    }

    private func showLanguageChangeAlert(_ lang: LocalizationManager.Language) {
        let alert = NSAlert()
        // 用目标语言显示提示，让用户能看懂
        let message = lang == .chinese
            ? "语言已切换为中文"
            : "Language changed to English"
        let info = lang == .chinese
            ? "重新启动 EasyPhoto 后生效。"
            : "Restart EasyPhoto to apply the change."
        let ok = lang == .chinese ? "好" : "OK"

        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .informational
        alert.addButton(withTitle: ok)
        alert.runModal()
    }
}

// MARK: - Notification 名称

extension Notification.Name {
    static let openImageFile = Notification.Name("openImageFile")
    static let openImageFolder = Notification.Name("openImageFolder")
}

// MARK: - AppDelegate（单窗口模式：双击新图片复用已有窗口）

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockIconIfAvailable()

        // A delayed retry helps when LaunchServices initially serves a stale cached icon.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.applyDockIconIfAvailable()
        }
    }

    private func applyDockIconIfAvailable() {
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
            return
        }

        if let icon = NSImage(named: "AppIcon") {
            NSApp.applicationIconImage = icon
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        // 激活已有窗口
        NSApp.activate(ignoringOtherApps: true)

        // 延迟发送，确保窗口已就绪；同时关闭多余窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let contentWindows = NSApp.windows.filter { w in
                w.isVisible && w.contentView != nil
                && !w.title.contains("Help") && !w.title.contains("帮助")
            }
            // 保留第一个，关闭其余
            if contentWindows.count > 1 {
                for window in contentWindows.dropFirst() {
                    window.close()
                }
            }
            if let mainWindow = contentWindows.first {
                mainWindow.makeKeyAndOrderFront(nil)
            }

            NotificationCenter.default.post(name: .openImageFile, object: url)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
            return false
        }
        return true
    }
}

// MARK: - Help 窗口

class OpenHelpWindowHelper {
    static let shared = OpenHelpWindowHelper()

    func open() {
        let helpView = NSHostingController(rootView: HelpView())
        let window = NSWindow(contentViewController: helpView)
        let loc = LocalizationManager.shared
        window.title = loc.s(.helpTitle)
        window.setContentSize(NSSize(width: 520, height: 560))
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
}
