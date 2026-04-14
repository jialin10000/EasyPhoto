//
//  ExifPanel.swift
//  EasyPhoto
//
//  EXIF 信息显示面板（浮动版，背景由调用方控制）
//

import SwiftUI

struct ExifPanel: View {
    let metadata: ImageMetadata?
    let imageURL: URL?
    @ObservedObject var loc = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽手柄
            DragHandle()

            // 内容区
            ScrollView {
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
                    if metadata?.lensModel != nil {
                        SectionView(title: loc.s(.exifLens)) {
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

                    // GPS 信息
                    if metadata?.hasGPS == true {
                        SectionView(title: loc.s(.exifLocation)) {
                            if let gps = metadata?.gpsFormatted {
                                InfoRow(label: loc.s(.exifCoordinates), value: gps)
                            }

                            if let altitude = metadata?.altitude {
                                InfoRow(label: loc.s(.exifAltitude), value: String(format: "%.1f m", altitude))
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
