//
//  EasyPhotoApp.swift
//  EasyPhoto
//
//  轻量级 Mac 看图软件 - 为摄影玩家打造
//

import SwiftUI

@main
struct EasyPhotoApp: App {
    @ObservedObject var loc = LocalizationManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(loc)
        }
        .windowStyle(.automatic)
        .commands {
            // 移除默认的 New Item
            CommandGroup(replacing: .newItem) { }

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
                    openHelpWindow()
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

    private func openHelpWindow() {
        OpenHelpWindowHelper.shared.open()
    }
}

// Helper 用于打开 Help 窗口
class OpenHelpWindowHelper {
    static let shared = OpenHelpWindowHelper()

    func open() {
        // 创建一个新窗口显示帮助
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
