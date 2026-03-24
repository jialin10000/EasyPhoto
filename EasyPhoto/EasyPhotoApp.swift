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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(loc)
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: .openImageFile,
                        object: url
                    )
                }
        }
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
                        loc.currentLanguage = lang
                    } label: {
                        HStack {
                            Text(lang.displayName)
                            if loc.currentLanguage == lang {
                                Text("✓")
                            }
                        }
                    }
                    .keyboardShortcut(lang == .chinese ? "1" : "2", modifiers: [.command, .shift])
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
}

// MARK: - Notification 名称

extension Notification.Name {
    static let openImageFile = Notification.Name("openImageFile")
    static let openImageFolder = Notification.Name("openImageFolder")
}

// MARK: - AppDelegate 处理系统双击打开文件

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        NotificationCenter.default.post(name: .openImageFile, object: url)
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
