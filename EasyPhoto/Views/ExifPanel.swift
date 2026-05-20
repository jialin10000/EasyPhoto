//
//  ExifPanel.swift
//  EasyPhoto
//
//  EXIF 信息显示面板（浮动版，背景由调用方控制）
//

import SwiftUI
import MapKit
import AppKit
import CoreLocation

struct ExifPanel: View {
    let metadata: ImageMetadata?
    let imageURL: URL?
    @ObservedObject var loc = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽手柄
            DragHandle()

            // 内容区
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    // 文件信息
                    if let url = imageURL {
                        SectionView(title: loc.s(.exifFile)) {
                            InfoRow(label: loc.s(.exifFilename), value: url.lastPathComponent)

                            if let size = metadata?.fileSizeFormatted {
                                InfoRow(label: loc.s(.exifFileSize), value: size)
                            }

                            if let resolution = metadata?.resolutionFormatted {
                                InfoRow(label: loc.s(.exifResolution), value: resolution)
                            }
                        }
                    }

                    // Location 信息（紧接 File，包含城市/国家文字 + 可点击小地图）
                    if metadata?.hasGPS == true,
                       let lat = metadata?.latitude,
                       let lon = metadata?.longitude {
                        SectionView(title: loc.s(.exifLocation)) {
                            if let gps = metadata?.gpsFormatted {
                                InfoRow(label: loc.s(.exifCoordinates), value: gps)
                            }

                            if let altitude = metadata?.altitude {
                                InfoRow(label: loc.s(.exifAltitude), value: String(format: "%.1f m", altitude))
                            }

                            GPSMapPreview(latitude: lat, longitude: lon)
                                .frame(height: 160)
                                .cornerRadius(8)
                                .padding(.top, 6)
                        }
                    }

                    // 相机信息
                    if metadata?.cameraModel != nil || metadata?.cameraMake != nil {
                        SectionView(title: loc.s(.exifCamera)) {
                            if let make = metadata?.cameraMake {
                                InfoRow(label: loc.s(.exifCameraMake), value: make)
                            }

                            if let model = metadata?.cameraModel {
                                InfoRow(label: loc.s(.exifCameraModel), value: model)
                            }
                        }
                    }

                    // 镜头信息
                    if metadata?.lensModel != nil || metadata?.lensMake != nil {
                        SectionView(title: loc.s(.exifLens)) {
                            if let make = metadata?.lensMake {
                                InfoRow(label: loc.s(.exifLensMake), value: make)
                            }
                            if let lens = metadata?.lensModel {
                                InfoRow(label: loc.s(.exifLensModel), value: lens)
                            }
                        }
                    }

                    // 拍摄参数
                    if hasShootingParams {
                        SectionView(title: loc.s(.exifShooting)) {
                            if let focal = metadata?.focalLengthFormatted {
                                InfoRow(label: loc.s(.exifFocalLength), value: focal)
                            }

                            if let aperture = metadata?.apertureFormatted {
                                InfoRow(label: loc.s(.exifAperture), value: aperture)
                            }

                            if let shutter = metadata?.shutterSpeedFormatted {
                                InfoRow(label: loc.s(.exifShutterSpeed), value: shutter)
                            }

                            if let iso = metadata?.isoFormatted {
                                InfoRow(label: loc.s(.exifISO), value: iso)
                            }

                            if let bias = metadata?.exposureBiasFormatted {
                                InfoRow(label: loc.s(.exifExposureBias), value: bias)
                            }

                            if let program = metadata?.exposureProgram {
                                InfoRow(label: loc.s(.exifExposureProgram), value: program)
                            }

                            if let metering = metadata?.meteringMode {
                                InfoRow(label: loc.s(.exifMeteringMode), value: metering)
                            }

                            // 对焦模式（MakerNote，部分相机支持）
                            if let focus = metadata?.focusMode {
                                InfoRow(label: loc.s(.exifFocusMode), value: focus)
                            }
                        }
                    }

                    // 时间信息
                    if metadata?.dateFormatted != nil {
                        SectionView(title: loc.s(.exifTime)) {
                            if let date = metadata?.dateFormatted {
                                InfoRow(label: loc.s(.exifOriginalDate), value: date)
                            }
                        }
                    }

                    // 无 EXIF 数据提示
                    if metadata == nil && imageURL != nil {
                        VStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.title2)
                                .foregroundColor(.secondary)

                            Text(loc.s(.exifNoInfo))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    private var hasShootingParams: Bool {
        return metadata?.focalLength != nil ||
               metadata?.aperture != nil ||
               metadata?.shutterSpeed != nil ||
               metadata?.iso != nil ||
               metadata?.exposureProgram != nil ||
               metadata?.meteringMode != nil ||
               metadata?.focusMode != nil
    }
}

// MARK: - 拖拽手柄

struct DragHandle: View {
    var body: some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 32, height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .cursor(.openHand)
    }
}

// MARK: - 子视图

struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 4) {
                content
            }
        }
        .padding(.bottom, 4)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 76, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - 光标辅助

private extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - GPS 小地图（地图上方显示城市/国家文字，点击地图打开 Apple Maps）

private struct GPSMapPreview: View {
    let latitude: Double
    let longitude: Double

    @State private var placeName: String?

    var body: some View {
        let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        VStack(alignment: .leading, spacing: 6) {
            // 反向地理编码得到的"城市, 国家"
            if let placeName = placeName, !placeName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(placeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // 地图 + 透明点击层（MKMapView 会抢 AppKit 鼠标事件，必须用上面盖一层来接收点击）
            Button(action: { openInAppleMaps() }) {
                ZStack(alignment: .bottomTrailing) {
                    Map(initialPosition: .region(region)) {
                        Marker("", coordinate: coord)
                    }
                    .id("\(latitude),\(longitude)")     // 切换照片时强制重建地图
                    .allowsHitTesting(false)

                    // 关键：透明层在 Map 之上，作为 Button 实际可点击区域
                    Color.clear
                        .contentShape(Rectangle())

                    // 右下角"打开 Apple Maps"提示
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(.black.opacity(0.45))
                        .clipShape(Circle())
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)
            .help("点击在 Apple Maps 中打开（查看更广区域）")
        }
        .onAppear { loadPlaceName() }
        .onChange(of: latitude) { _, _ in loadPlaceName() }
        .onChange(of: longitude) { _, _ in loadPlaceName() }
    }

    private func loadPlaceName() {
        placeName = nil
        let location = CLLocation(latitude: latitude, longitude: longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            guard let p = placemarks?.first else { return }
            let city = p.locality ?? p.subAdministrativeArea ?? p.administrativeArea ?? ""
            let country = p.country ?? ""
            let joined = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
            DispatchQueue.main.async { placeName = joined }
        }
    }

    private func openInAppleMaps() {
        let urlString = "https://maps.apple.com/?ll=\(latitude),\(longitude)&q=\(latitude),\(longitude)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    var meta = ImageMetadata()
    meta.cameraMake = "Sony"
    meta.cameraModel = "ILCE-7RM5"
    meta.lensModel = "FE 85mm F1.4 GM"
    meta.focalLength = 85
    meta.aperture = 1.4
    meta.shutterSpeed = 1.0 / 500.0
    meta.iso = 200
    meta.exposureBias = -0.3
    meta.exposureProgram = "A"
    meta.meteringMode = "Multi-segment"
    meta.focusMode = "AF-S"
    meta.dateTimeOriginal = Date()
    meta.latitude = 31.2304
    meta.longitude = 121.4737
    meta.altitude = 10
    meta.imageWidth = 7952
    meta.imageHeight = 5304
    meta.fileSize = 45_000_000
    return ExifPanel(
        metadata: meta,
        imageURL: URL(fileURLWithPath: "/test/DSC00001.ARW")
    )
    .frame(width: 280, height: 600)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
