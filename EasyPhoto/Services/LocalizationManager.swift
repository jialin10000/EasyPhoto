//
//  LocalizationManager.swift
//  EasyPhoto
//
//  多语言管理：中英双语支持，自动检测系统语言
//

import SwiftUI
import Combine

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: Language {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "appLanguage")
        }
    }

    enum Language: String, CaseIterable {
        case chinese = "zh"
        case english = "en"

        var displayName: String {
            switch self {
            case .chinese: return "中文"
            case .english: return "English"
            }
        }
    }

    private init() {
        // 优先读取用户手动选择的语言
        if let saved = UserDefaults.standard.string(forKey: "appLanguage"),
           let lang = Language(rawValue: saved) {
            currentLanguage = lang
        } else {
            // 自动检测系统语言
            let preferredLanguage = Locale.preferredLanguages.first ?? "en"
            currentLanguage = preferredLanguage.hasPrefix("zh") ? .chinese : .english
        }
    }

    // MARK: - 本地化字符串

    func s(_ key: StringKey) -> String {
        switch currentLanguage {
        case .chinese: return key.zh
        case .english: return key.en
        }
    }
}

// MARK: - 所有本地化字符串

enum StringKey {
    // 欢迎界面
    case dropHint
    case formatHint
    case shortcutHint

    // 幻灯片
    case slideshowPlaying
    case slideshowStop

    // EXIF 面板
    case exifFile
    case exifCamera
    case exifLens
    case exifShooting
    case exifTime
    case exifLocation
    case exifFilename
    case exifResolution
    case exifFileSize
    case exifColorSpace
    case exifCameraMake
    case exifCameraModel
    case exifLensModel
    case exifLensMake
    case exifFocalLength
    case exifAperture
    case exifShutterSpeed
    case exifISO
    case exifExposureBias
    case exifOriginalDate
    case exifDigitizedDate
    case exifCoordinates
    case exifAltitude
    case exifNoInfo

    // 菜单
    case menuLanguage
    case menuHelp
    case menuAbout

    // Help 窗口
    case helpTitle
    case helpBasicTitle
    case helpBasicDragDrop
    case helpBasicFormats
    case helpNavigationTitle
    case helpNavClickLeft
    case helpNavClickRight
    case helpNavArrowKeys
    case helpShortcutsTitle
    case helpShortcutSlideshow
    case helpShortcutExif
    case helpShortcutFullscreen
    case helpShortcutZoomIn
    case helpShortcutZoomReset
    case helpShortcutDrag
    case helpTipsTitle
    case helpTipFolder
    case helpTipExif

    var zh: String {
        switch self {
        case .dropHint: return "拖拽图片到这里"
        case .formatHint: return "支持 JPG、HEIC、PNG、RAW 等格式"
        case .shortcutHint: return "快捷键：← → 切换图片 | 点击左/右侧切换 | S 幻灯片 | I 信息 | F 全屏"
        case .slideshowPlaying: return "▶ 幻灯片播放中"
        case .slideshowStop: return "按 S 停止"
        case .exifFile: return "文件"
        case .exifCamera: return "相机"
        case .exifLens: return "镜头"
        case .exifShooting: return "拍摄参数"
        case .exifTime: return "时间"
        case .exifLocation: return "位置"
        case .exifFilename: return "文件名"
        case .exifResolution: return "分辨率"
        case .exifFileSize: return "文件大小"
        case .exifColorSpace: return "色彩空间"
        case .exifCameraMake: return "制造商"
        case .exifCameraModel: return "型号"
        case .exifLensModel: return "镜头型号"
        case .exifLensMake: return "镜头制造商"
        case .exifFocalLength: return "焦距"
        case .exifAperture: return "光圈"
        case .exifShutterSpeed: return "快门速度"
        case .exifISO: return "ISO"
        case .exifExposureBias: return "曝光补偿"
        case .exifOriginalDate: return "拍摄时间"
        case .exifDigitizedDate: return "数字化时间"
        case .exifCoordinates: return "坐标"
        case .exifAltitude: return "海拔"
        case .exifNoInfo: return "拖入图片以查看 EXIF 信息"
        case .menuLanguage: return "语言"
        case .menuHelp: return "使用帮助"
        case .menuAbout: return "关于 EasyPhoto"
        case .helpTitle: return "EasyPhoto 使用帮助"
        case .helpBasicTitle: return "基本操作"
        case .helpBasicDragDrop: return "将图片文件拖拽到窗口中即可查看"
        case .helpBasicFormats: return "支持格式：JPG、JPEG、PNG、HEIC、HEIF、TIFF、GIF、BMP、RAW（CR2、CR3、NEF、ARW、ORF、RW2、DNG）"
        case .helpNavigationTitle: return "图片导航"
        case .helpNavClickLeft: return "点击图片左半区 → 上一张"
        case .helpNavClickRight: return "点击图片右半区 → 下一张"
        case .helpNavArrowKeys: return "← → 方向键切换图片"
        case .helpShortcutsTitle: return "快捷键"
        case .helpShortcutSlideshow: return "S — 开始/停止幻灯片播放（每 3 秒切换）"
        case .helpShortcutExif: return "I — 显示/隐藏 EXIF 信息面板"
        case .helpShortcutFullscreen: return "F — 进入/退出全屏"
        case .helpShortcutZoomIn: return "双击图片 — 放大到 2 倍"
        case .helpShortcutZoomReset: return "放大时双击 — 恢复原始大小"
        case .helpShortcutDrag: return "放大时拖拽 — 平移图片"
        case .helpTipsTitle: return "使用技巧"
        case .helpTipFolder: return "拖入一张图片后，会自动加载同文件夹下的所有图片，方便浏览"
        case .helpTipExif: return "EXIF 面板显示详细的相机、镜头、拍摄参数和 GPS 位置信息"
        }
    }

    var en: String {
        switch self {
        case .dropHint: return "Drop images here"
        case .formatHint: return "Supports JPG, HEIC, PNG, RAW and more"
        case .shortcutHint: return "Shortcuts: ← → switch | Click left/right side | S slideshow | I info | F fullscreen"
        case .slideshowPlaying: return "▶ Slideshow playing"
        case .slideshowStop: return "Press S to stop"
        case .exifFile: return "File"
        case .exifCamera: return "Camera"
        case .exifLens: return "Lens"
        case .exifShooting: return "Shooting"
        case .exifTime: return "Time"
        case .exifLocation: return "Location"
        case .exifFilename: return "Filename"
        case .exifResolution: return "Resolution"
        case .exifFileSize: return "File Size"
        case .exifColorSpace: return "Color Space"
        case .exifCameraMake: return "Make"
        case .exifCameraModel: return "Model"
        case .exifLensModel: return "Lens Model"
        case .exifLensMake: return "Lens Make"
        case .exifFocalLength: return "Focal Length"
        case .exifAperture: return "Aperture"
        case .exifShutterSpeed: return "Shutter Speed"
        case .exifISO: return "ISO"
        case .exifExposureBias: return "Exposure Bias"
        case .exifOriginalDate: return "Date Taken"
        case .exifDigitizedDate: return "Date Digitized"
        case .exifCoordinates: return "Coordinates"
        case .exifAltitude: return "Altitude"
        case .exifNoInfo: return "Drop an image to view EXIF info"
        case .menuLanguage: return "Language"
        case .menuHelp: return "Help Guide"
        case .menuAbout: return "About EasyPhoto"
        case .helpTitle: return "EasyPhoto Help"
        case .helpBasicTitle: return "Getting Started"
        case .helpBasicDragDrop: return "Drag and drop an image file into the window to view it"
        case .helpBasicFormats: return "Supported formats: JPG, JPEG, PNG, HEIC, HEIF, TIFF, GIF, BMP, RAW (CR2, CR3, NEF, ARW, ORF, RW2, DNG)"
        case .helpNavigationTitle: return "Navigation"
        case .helpNavClickLeft: return "Click left side of image → Previous"
        case .helpNavClickRight: return "Click right side of image → Next"
        case .helpNavArrowKeys: return "← → arrow keys to switch images"
        case .helpShortcutsTitle: return "Keyboard Shortcuts"
        case .helpShortcutSlideshow: return "S — Start/stop slideshow (3s interval)"
        case .helpShortcutExif: return "I — Toggle EXIF info panel"
        case .helpShortcutFullscreen: return "F — Toggle fullscreen"
        case .helpShortcutZoomIn: return "Double-click — Zoom to 2x"
        case .helpShortcutZoomReset: return "Double-click when zoomed — Reset to original"
        case .helpShortcutDrag: return "Drag when zoomed — Pan image"
        case .helpTipsTitle: return "Tips"
        case .helpTipFolder: return "Dropping one image automatically loads all images in the same folder for easy browsing"
        case .helpTipExif: return "The EXIF panel shows detailed camera, lens, shooting parameters and GPS location"
        }
    }
}
