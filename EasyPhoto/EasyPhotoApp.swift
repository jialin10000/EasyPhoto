//
//  EasyPhotoApp.swift
//  EasyPhoto
//
//  轻量级 Mac 看图软件 - 为摄影玩家打造
//

import SwiftUI

@main
struct EasyPhotoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .commands {
            // 添加自定义菜单命令
            CommandGroup(replacing: .newItem) { }
        }
    }
}
