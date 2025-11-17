//
//  TemplateLoader.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation
import CoreGraphics
import AppKit

/// Loads and prepares all template images (27 files) for later matching.
/// Responsible for:
/// - Discovering template PNG files
/// - Parsing filename → TemplateKey
/// - Loading CGImage
/// - Preprocessing to grayscale feature vectors
protocol TemplateLoaderProtocol {

    /// Load all templates from a given folder URL (or bundle resource URL).
    /// - Parameters:
    ///   - rootURL: Folder that contains the PNG files.
    ///   - resolutionSuffix: e.g. "3840_2160". If provided, only filenames
    ///     whose basename ends with "_<resolutionSuffix>" will be loaded.
    /// - Returns: Dictionary keyed by TemplateKey.
    ///   Throws if critical I/O or decoding errors occur.
    func loadTemplates(
        from rootURL: URL,
        resolutionSuffix: String?
    ) throws -> [TemplateKey: TemplateDescriptor]
}

/// Convenience overload if你不想按分辨率过滤
extension TemplateLoaderProtocol {
    func loadTemplates(from rootURL: URL) throws -> [TemplateKey: TemplateDescriptor] {
        try loadTemplates(from: rootURL, resolutionSuffix: nil)
    }
}

enum TemplateLoaderError: Error {
    case directoryNotFound(URL)
    case noPNGFilesFound(URL)
    case imageDecodeFailed(URL)
    case filenameParsingFailed(String)
    case preprocessingFailed(String)
}

/// Default implementation of TemplateLoaderProtocol for macOS.
/// Assumes filenames like:
///   blackPawn_blue_3840_2160.png
///   empty_yellow_3840_2160.png
///   empty_previous_3840_2160.png
final class DefaultTemplateLoader: TemplateLoaderProtocol {

    // 统一的目标尺寸（模板 & 棋盘小格都缩放到这个尺寸做匹配）
    private let targetSize: Int = 64

    // MARK: - Public API

    func loadTemplates(
        from rootURL: URL,
        resolutionSuffix: String?
    ) throws -> [TemplateKey: TemplateDescriptor] {

        print("🧩 TemplateLoader: rootURL = \(rootURL.path)")
        let fm = FileManager.default

        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDir), isDir.boolValue else {
            print("❌ TemplateLoader: directory not found")
            throw TemplateLoaderError.directoryNotFound(rootURL)
        }

        let allFiles = try fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        // 只保留 .png
        var pngFiles = allFiles.filter { $0.pathExtension.lowercased() == "png" }

        // 如果指定了分辨率后缀，例如 "3840_2160"，只保留 basename 以 "_3840_2160" 结尾的文件
        if let suffix = resolutionSuffix, !suffix.isEmpty {
            let pattern = "_\(suffix)"
            pngFiles = pngFiles.filter { url in
                let base = url.deletingPathExtension().lastPathComponent
                return base.hasSuffix(pattern)
            }
        }

        guard !pngFiles.isEmpty else {
            print("❌ TemplateLoader: no PNG files found")
            throw TemplateLoaderError.noPNGFilesFound(rootURL)
        }

        print("🧩 TemplateLoader: found \(pngFiles.count) PNG files")

        var result: [TemplateKey: TemplateDescriptor] = [:]

        for url in pngFiles.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let baseName = url.deletingPathExtension().lastPathComponent
            print("🧩 TemplateLoader: processing \(baseName).png")

            do {
                let key = try parseTemplateKey(from: baseName)

                guard
                    let nsImage = NSImage(contentsOf: url),
                    let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                else {
                    print("❌ TemplateLoader: imageDecodeFailed for \(url.lastPathComponent)")
                    throw TemplateLoaderError.imageDecodeFailed(url)
                }

                let descriptor = try makeDescriptor(from: cgImage, key: key)
                result[key] = descriptor

                print("✅ TemplateLoader: added template for key \(key)")
            } catch {
                print("❌ TemplateLoader: filenameParsingFailed or preprocessingFailed for \(baseName): \(error)")
                // 对单个文件解析失败，直接抛出（也可以选择跳过，看你需求）
                throw error
            }
        }

        print("✅ TemplateLoader: total \(result.count) templates loaded")
        return result
    }

    // MARK: - Filename parsing

    /// Parse a filename (without extension) into TemplateKey.
    /// Supported patterns:
    ///   - "blackPawn_blue_3840_2160"
    ///   - "whiteQueen_yellow_3840_2160"
    ///   - "empty_blue_3840_2160"
    ///   - "empty_previous_3840_2160"
    ///
    /// Rules:
    ///   - pieceColor: white / black / none (for empty)
    ///   - pieceKind: pawn/knight/bishop/rook/queen/king/empty
    ///   - background: blue / yellow / previous
    func parseTemplateKey(from baseName: String) throws -> TemplateKey {
        // 按 '_' 切分，前三个 token 里包含了颜色、棋子和背景，其余可能是分辨率
        let parts = baseName.split(separator: "_")
        guard parts.count >= 2 else {
            throw TemplateLoaderError.filenameParsingFailed(baseName)
        }

        let first = String(parts[0])        // "blackPawn" / "whiteQueen" / "empty"
        let second = String(parts[1])       // "blue" / "yellow" / "previous"

        // 1) 解析背景
        let background: BackgroundKind
        switch second.lowercased() {
        case "blue":
            background = .blue
        case "yellow":
            background = .yellow
        case "previous":
            background = .previous
        default:
            throw TemplateLoaderError.filenameParsingFailed(baseName)
        }

        // 2) 解析棋子 & 颜色
        if first.lowercased() == "empty" {
            return TemplateKey(
                pieceColor: .none,
                pieceKind: .empty,
                background: background
            )
        }

        // 否则是类似 "blackPawn" / "whiteKnight"
        let lower = first.lowercased()

        let pieceColor: PieceColor
        let pieceName: String

        if lower.hasPrefix("white") {
            pieceColor = .white
            pieceName = String(first.dropFirst("white".count))
        } else if lower.hasPrefix("black") {
            pieceColor = .black
            pieceName = String(first.dropFirst("black".count))
        } else {
            throw TemplateLoaderError.filenameParsingFailed(baseName)
        }

        let pieceKind: PieceKind
        switch pieceName.lowercased() {
        case "pawn":
            pieceKind = .pawn
        case "knight":
            pieceKind = .knight
        case "bishop":
            pieceKind = .bishop
        case "rook":
            pieceKind = .rook
        case "queen":
            pieceKind = .queen
        case "king":
            pieceKind = .king
        default:
            throw TemplateLoaderError.filenameParsingFailed(baseName)
        }

        return TemplateKey(
            pieceColor: pieceColor,
            pieceKind: pieceKind,
            background: background
        )
    }

    // MARK: - Image preprocessing

    /// Convert CGImage into a TemplateDescriptor, including grayscale vector.
    /// - Parameters:
    ///   - image: Source CGImage.
    ///   - key:   Already parsed TemplateKey.
    /// - Returns: TemplateDescriptor with preprocessed data filled.
    func makeDescriptor(from image: CGImage, key: TemplateKey) throws -> TemplateDescriptor {
        let width = targetSize
        let height = targetSize

        // 灰度 color space
        guard let colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2) else {
            throw TemplateLoaderError.preprocessingFailed("Cannot create gray colorspace")
        }

        // 每像素 1 字节，8 bits
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8

        // 创建 Bitmap 上下文
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw TemplateLoaderError.preprocessingFailed("Cannot create CGContext")
        }

        // 在灰度 context 中绘制并缩放原图
        context.interpolationQuality = .high
        let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.draw(image, in: rect)

        // 拿到像素数据
        guard let data = context.data else {
            throw TemplateLoaderError.preprocessingFailed("Context has no data")
        }

        // 将内存视为 UInt8 数组
        let count = width * height
        let buffer = data.bindMemory(to: UInt8.self, capacity: count)
        var vector = [Float](repeating: 0, count: count)

        for i in 0..<count {
            vector[i] = Float(buffer[i]) / 255.0
        }

        return TemplateDescriptor(
            key: key,
            width: width,
            height: height,
            grayscaleVector: vector
        )
    }
}
