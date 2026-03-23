//
//  HelpView.swift
//  EasyPhoto
//
//  使用帮助窗口 - 显示版本号、快捷键和使用方法
//

import SwiftUI

struct HelpView: View {
    @ObservedObject var loc = LocalizationManager.shared

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 标题和版本
                HStack {
                    if let appIcon = NSImage(named: "AppIcon") {
                        Image(nsImage: appIcon)
                            .resizable()
                            .frame(width: 64, height: 64)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EasyPhoto")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(appVersion)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // 基本操作
                helpSection(title: loc.s(.helpBasicTitle), items: [
                    loc.s(.helpBasicDragDrop),
                    loc.s(.helpBasicFormats),
                ])

                // 图片导航
                helpSection(title: loc.s(.helpNavigationTitle), items: [
                    loc.s(.helpNavClickLeft),
                    loc.s(.helpNavClickRight),
                    loc.s(.helpNavArrowKeys),
                ])

                // 快捷键
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc.s(.helpShortcutsTitle))
                        .font(.headline)

                    shortcutRow(key: "S", desc: loc.s(.helpShortcutSlideshow))
                    shortcutRow(key: "I", desc: loc.s(.helpShortcutExif))
                    shortcutRow(key: "F", desc: loc.s(.helpShortcutFullscreen))
                    shortcutRow(key: "⇧ Click", desc: loc.s(.helpShortcutZoomIn))
                    shortcutRow(key: "⇧⇧ Click", desc: loc.s(.helpShortcutZoomReset))
                    shortcutRow(key: "Drag", desc: loc.s(.helpShortcutDrag))
                }

                // 使用技巧
                helpSection(title: loc.s(.helpTipsTitle), items: [
                    loc.s(.helpTipFolder),
                    loc.s(.helpTipExif),
                ])

                Spacer()
            }
            .padding(30)
        }
        .frame(width: 520, height: 560)
    }

    private func helpSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(.accentColor)
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func shortcutRow(key: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(minWidth: 80, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(5)
            Text(desc)
        }
    }
}
