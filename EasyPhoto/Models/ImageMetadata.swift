//
//  ImageMetadata.swift
//  EasyPhoto
//
//  EXIF 数据模型
//

import Foundation

struct ImageMetadata {
    // 相机信息
    var cameraMake: String?          // 相机品牌 (Canon, Sony, Nikon...)
    var cameraModel: String?         // 相机型号 (A7R5, R5, Z8...)
    
    // 镜头信息
    var lensModel: String?           // 镜头型号
    var lensMake: String?            // 镜头品牌
    
    // 拍摄参数
    var focalLength: Double?         // 焦距 (mm)
    var focalLength35mm: Double?     // 等效 35mm 焦距
    var aperture: Double?            // 光圈 (f/1.4 -> 1.4)
    var shutterSpeed: Double?        // 快门速度 (秒)
    var iso: Int?                    // ISO 感光度
    var exposureBias: Double?        // 曝光补偿
    
    // 时间信息
    var dateTimeOriginal: Date?      // 拍摄时间
    var dateTimeDigitized: Date?     // 数字化时间
    
    // GPS 信息
    var latitude: Double?            // 纬度
    var longitude: Double?           // 经度
    var altitude: Double?            // 海拔
    
    // 图片信息
    var imageWidth: Int?             // 图片宽度
    var imageHeight: Int?            // 图片高度
    var colorSpace: String?          // 色彩空间
    var fileSize: Int64?             // 文件大小 (bytes)
    var fileName: String?            // 文件名
    
    // MARK: - 格式化输出
    
    /// 格式化快门速度显示 (如 1/500s)
    var shutterSpeedFormatted: String? {
        guard let speed = shutterSpeed else { return nil }
        
        if speed >= 1 {
            return String(format: "%.1fs", speed)
        } else {
            let denominator = Int(round(1.0 / speed))
            return "1/\(denominator)s"
        }
    }
    
    /// 格式化光圈显示 (如 f/1.4)
    var apertureFormatted: String? {
        guard let f = aperture else { return nil }
        
        if f == floor(f) {
            return String(format: "f/%.0f", f)
        } else {
            return String(format: "f/%.1f", f)
        }
    }
    
    /// 格式化焦距显示 (如 85mm)
    var focalLengthFormatted: String? {
        guard let focal = focalLength else { return nil }
        
        var result = String(format: "%.0fmm", focal)
        
        // 添加等效焦距
        if let focal35 = focalLength35mm, focal35 != focal {
            result += String(format: " (等效 %.0fmm)", focal35)
        }
        
        return result
    }
    
    /// 格式化 ISO 显示
    var isoFormatted: String? {
        guard let iso = iso else { return nil }
        return "ISO \(iso)"
    }
    
    /// 格式化曝光补偿
    var exposureBiasFormatted: String? {
        guard let bias = exposureBias else { return nil }
        
        if bias == 0 {
            return "±0 EV"
        } else if bias > 0 {
            return String(format: "+%.1f EV", bias)
        } else {
            return String(format: "%.1f EV", bias)
        }
    }
    
    /// 格式化拍摄日期
    var dateFormatted: String? {
        guard let date = dateTimeOriginal else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    /// 格式化文件大小
    var fileSizeFormatted: String? {
        guard let size = fileSize else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// 格式化分辨率
    var resolutionFormatted: String? {
        guard let width = imageWidth, let height = imageHeight else { return nil }
        
        let megapixels = Double(width * height) / 1_000_000
        return "\(width) × \(height) (\(String(format: "%.1f", megapixels)) MP)"
    }
    
    /// GPS 坐标格式化
    var gpsFormatted: String? {
        guard let lat = latitude, let lon = longitude else { return nil }
        
        let latDir = lat >= 0 ? "N" : "S"
        let lonDir = lon >= 0 ? "E" : "W"
        
        return String(format: "%.6f° %@, %.6f° %@", abs(lat), latDir, abs(lon), lonDir)
    }
    
    /// 是否有 GPS 数据
    var hasGPS: Bool {
        return latitude != nil && longitude != nil
    }
}
