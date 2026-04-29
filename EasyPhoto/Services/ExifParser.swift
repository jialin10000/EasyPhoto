//
//  ExifParser.swift
//  EasyPhoto
//
//  EXIF 数据解析服务 - 使用 ImageIO 框架
//

import Foundation
import ImageIO
import CoreLocation

class ExifParser {
    
    /// 从图片文件解析 EXIF 数据
    static func parse(from url: URL) -> ImageMetadata? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("无法创建图片源: \(url.path)")
            return nil
        }
        
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            print("无法获取图片属性: \(url.path)")
            return nil
        }
        
        var metadata = ImageMetadata()
        
        // 获取文件信息
        if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path) {
            metadata.fileSize = fileAttributes[.size] as? Int64
        }
        metadata.fileName = url.lastPathComponent
        
        // 解析图片尺寸
        metadata.imageWidth = properties[kCGImagePropertyPixelWidth as String] as? Int
        metadata.imageHeight = properties[kCGImagePropertyPixelHeight as String] as? Int
        metadata.colorSpace = properties[kCGImagePropertyColorModel as String] as? String
        
        // 解析 EXIF 数据
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            parseExif(exif: exif, metadata: &metadata)
        }
        
        // 解析 TIFF 数据 (包含相机信息)
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            parseTiff(tiff: tiff, metadata: &metadata)
        }
        
        // 解析 GPS 数据
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            parseGPS(gps: gps, metadata: &metadata)
        }
        
        // 解析 EXIF Aux 数据 (镜头信息)
        if let exifAux = properties[kCGImagePropertyExifAuxDictionary as String] as? [String: Any] {
            parseExifAux(exifAux: exifAux, metadata: &metadata)
        }

        // 解析 MakerNote 中的对焦模式（各厂商私有，尽力而为）
        parseMakerNote(properties: properties, metadata: &metadata)

        return metadata
    }
    
    // MARK: - Private Methods
    
    private static func parseExif(exif: [String: Any], metadata: inout ImageMetadata) {
        // 曝光时间 (快门速度)
        if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? Double {
            metadata.shutterSpeed = exposureTime
        }
        
        // 光圈
        if let fNumber = exif[kCGImagePropertyExifFNumber as String] as? Double {
            metadata.aperture = fNumber
        }
        
        // ISO
        if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int],
           let iso = isoArray.first {
            metadata.iso = iso
        }
        
        // 焦距
        if let focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double {
            metadata.focalLength = focalLength
        }
        
        // 等效 35mm 焦距
        if let focalLength35 = exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? Double {
            metadata.focalLength35mm = focalLength35
        }
        
        // 曝光补偿
        if let exposureBias = exif[kCGImagePropertyExifExposureBiasValue as String] as? Double {
            metadata.exposureBias = exposureBias
        }
        
        // 拍摄日期
        if let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
            metadata.dateTimeOriginal = parseExifDate(dateString)
        }
        
        // 数字化日期
        if let dateString = exif[kCGImagePropertyExifDateTimeDigitized as String] as? String {
            metadata.dateTimeDigitized = parseExifDate(dateString)
        }
        
        // 镜头型号 (部分相机在 EXIF 中)
        if let lensModel = exif[kCGImagePropertyExifLensModel as String] as? String {
            metadata.lensModel = lensModel
        }
        
        // 镜头品牌
        if let lensMake = exif[kCGImagePropertyExifLensMake as String] as? String {
            metadata.lensMake = lensMake
        }

        // 曝光程序 (P/A/S/M 等，标准 EXIF 字段，兼容性好)
        if let program = exif[kCGImagePropertyExifExposureProgram as String] as? Int {
            metadata.exposureProgram = decodeExposureProgram(program)
        }

        // 测光模式
        if let metering = exif[kCGImagePropertyExifMeteringMode as String] as? Int {
            metadata.meteringMode = decodeMeteringMode(metering)
        }
    }
    
    private static func parseTiff(tiff: [String: Any], metadata: inout ImageMetadata) {
        // 相机品牌
        if let make = tiff[kCGImagePropertyTIFFMake as String] as? String {
            metadata.cameraMake = cleanString(make)
        }
        
        // 相机型号
        if let model = tiff[kCGImagePropertyTIFFModel as String] as? String {
            metadata.cameraModel = cleanString(model)
        }
    }
    
    private static func parseGPS(gps: [String: Any], metadata: inout ImageMetadata) {
        // 纬度
        if let latitude = gps[kCGImagePropertyGPSLatitude as String] as? Double,
           let latitudeRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String {
            metadata.latitude = latitudeRef == "S" ? -latitude : latitude
        }
        
        // 经度
        if let longitude = gps[kCGImagePropertyGPSLongitude as String] as? Double,
           let longitudeRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
            metadata.longitude = longitudeRef == "W" ? -longitude : longitude
        }
        
        // 海拔
        if let altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double {
            let altitudeRef = gps[kCGImagePropertyGPSAltitudeRef as String] as? Int ?? 0
            metadata.altitude = altitudeRef == 1 ? -altitude : altitude
        }
    }
    
    private static func parseExifAux(exifAux: [String: Any], metadata: inout ImageMetadata) {
        // 镜头型号 (备用来源)
        if metadata.lensModel == nil {
            if let lensModel = exifAux[kCGImagePropertyExifAuxLensModel as String] as? String {
                metadata.lensModel = lensModel
            }
        }
    }
    
    // MARK: - MakerNote（厂商私有数据，用于对焦模式等）

    private static func parseMakerNote(properties: [String: Any], metadata: inout ImageMetadata) {
        // Sony / Minolta（Sony 沿用 Minolta MakerNote 格式）
        if let makerMinolta = properties[kCGImagePropertyMakerMinoltaDictionary as String] as? [String: Any] {
            if let focusRaw = makerMinolta["FocusMode"] as? Int {
                metadata.focusMode = decodeSonyFocusMode(focusRaw)
            }
        }

        // Canon
        if metadata.focusMode == nil,
           let makerCanon = properties[kCGImagePropertyMakerCanonDictionary as String] as? [String: Any] {
            // CanonCameraSettings 数组，index 7 = FocusMode（部分型号）
            if let settings = makerCanon["CanonCameraSettings"] as? [Any],
               settings.count > 7,
               let focusRaw = settings[7] as? Int {
                metadata.focusMode = decodeCanonFocusMode(focusRaw)
            }
        }

        // Nikon / Fuji / 其他：若 ImageIO 暴露了 FocusMode 键，直接读取
        if metadata.focusMode == nil {
            let makerKeys = [
                kCGImagePropertyMakerNikonDictionary as String,
                kCGImagePropertyMakerFujiDictionary as String,
            ]
            for key in makerKeys {
                if let dict = properties[key] as? [String: Any] {
                    if let focusStr = dict["FocusMode"] as? String, !focusStr.isEmpty {
                        metadata.focusMode = focusStr
                        break
                    } else if let focusRaw = dict["FocusMode"] as? Int {
                        metadata.focusMode = "Mode \(focusRaw)"
                        break
                    }
                }
            }
        }
    }

    // MARK: - 解码辅助

    private static func decodeSonyFocusMode(_ value: Int) -> String {
        switch value {
        case 0: return "AF-S"
        case 1: return "AF-C"
        case 2: return "AF-A"
        case 3: return "MF"
        case 4: return "Permanent AF"
        case 6: return "DMF"
        case 7: return "AF-D"
        default: return "Unknown (\(value))"
        }
    }

    private static func decodeCanonFocusMode(_ value: Int) -> String {
        switch value {
        case 0: return "One-Shot AF"
        case 1: return "AI Servo AF"
        case 2: return "AI Focus AF"
        case 3: return "MF"
        case 4: return "Single"
        case 5: return "Continuous"
        case 6: return "MF"
        default: return "Unknown (\(value))"
        }
    }

    private static func decodeExposureProgram(_ value: Int) -> String {
        switch value {
        case 0: return "Not Defined"
        case 1: return "Manual (M)"
        case 2: return "Program (P)"
        case 3: return "Aperture Priority (A)"
        case 4: return "Shutter Priority (S)"
        case 5: return "Creative (Depth)"
        case 6: return "Action (Speed)"
        case 7: return "Portrait"
        case 8: return "Landscape"
        default: return "Unknown"
        }
    }

    private static func decodeMeteringMode(_ value: Int) -> String {
        switch value {
        case 1: return "Average"
        case 2: return "Center-weighted"
        case 3: return "Spot"
        case 4: return "Multi-spot"
        case 5: return "Multi-segment"
        case 6: return "Partial"
        default: return "Unknown"
        }
    }

    // MARK: - Helper Methods

    private static let exifDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f
    }()

    private static func parseExifDate(_ dateString: String) -> Date? {
        return exifDateFormatter.date(from: dateString)
    }
    
    private static func cleanString(_ string: String) -> String {
        // 移除多余的空格和换行
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
