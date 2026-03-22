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
        
        // 解析 MakerNote 中的镜头信息 (部分相机)
        // 注意：MakerNote 格式因厂商而异，这里只做基本支持
        
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
    
    // MARK: - Helper Methods
    
    private static func parseExifDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
    
    private static func cleanString(_ string: String) -> String {
        // 移除多余的空格和换行
        return string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
