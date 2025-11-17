//
//  TemplateLoader.swift
//  ChessApp
//
//  Created by stone on 2025/11/17.
//

import Foundation
import AppKit
import CoreGraphics

/// 模板加载相关错误
enum TemplateLoaderError: Error {
    case cannotListDirectory(URL)
    case cannotLoadImage(URL)
    case cannotCreateCGImage(URL)
    case invalidFileName(String)
}

/// 负责从 Bundle 资源中加载所有棋子模板图片，并构造模板字典。
///
/// 约定文件命名格式：
///   - 棋子类模板：
///       blackPawn_blue_3840_2160.png
///       whiteKing_yellow_3840_2160.png
///   - 空格模板：
///       empty_blue_3840_2160.png
///       empty_yellow_3840_2160.png
///       empty_previous_3840_2160.png
///
/// 其中：
///   - 前缀部分（第一个下划线之前）用于解析棋子颜色/类型：
///       blackPawn, whiteBishop, empty
///   - 第二个 token 是背景：blue / yellow / previous
///   - 后面所有 token 合起来作为分辨率后缀（例如 "3840_2160"）
///
/// 加载时会根据 `resolutionSuffix` 过滤文件名后缀：
///   *_<resolutionSuffix>.png
///
/// ⚠️ 确保你的 TemplateDescriptor 已经定义为：
///
///   struct TemplateDescriptor {
///       let key: TemplateKey
///       let width: Int
///       let height: Int
///       let grayscaleVector: [Float]
///       let cgImage: CGImage      // ✅ 必须有这个字段
///   }
///
final class DefaultTemplateLoader {
    
    // MARK: - Public API
    
    /// 从指定目录加载所有模板 PNG，按 `resolutionSuffix` 过滤。
    ///
    /// - Parameters:
    ///   - rootURL: Bundle 资源目录，如 `Bundle.main.resourceURL!`
    ///   - resolutionSuffix: 例如 "3840_2160" 或 "1920_1080"
    ///
    /// - Returns: `[TemplateKey : TemplateDescriptor]`
    func loadTemplates(
        from rootURL: URL,
        resolutionSuffix: String
    ) throws -> [TemplateKey: TemplateDescriptor] {
        
        var result: [TemplateKey: TemplateDescriptor] = [:]
        let fm = FileManager.default
        
        print("🔍 Templates folder = \(rootURL.path)")
        print("🧩 TemplateLoader: rootURL = \(rootURL.path)")
        
        let files: [URL]
        do {
            files = try fm.contentsOfDirectory(
                at: rootURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        } catch {
            print("❌ TemplateLoader: cannot list directory: \(error)")
            throw TemplateLoaderError.cannotListDirectory(rootURL)
        }
        
        // 只要 PNG，并且文件名以 "_\(resolutionSuffix).png" 结尾
        let suffix = "_\(resolutionSuffix).png"
        let pngs = files.filter { url in
            url.pathExtension.lowercased() == "png" &&
            url.lastPathComponent.hasSuffix(suffix)
        }
        
        print("🧩 TemplateLoader: found \(pngs.count) PNG files for resolutionSuffix=\(resolutionSuffix)")
        
        for url in pngs {
            autoreleasepool {
                let fileName = url.lastPathComponent
                print("🧩 TemplateLoader: processing \(fileName)")
                
                // 1️⃣ 加载 NSImage / CGImage
                guard let nsImage = NSImage(contentsOf: url) else {
                    print("⚠️ Cannot load image at \(fileName)")
                    return
                }
                guard let cg = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    print("⚠️ Cannot get CGImage for \(fileName)")
                    return
                }
                
                // 2️⃣ 从文件名解析 TemplateKey
                guard let key = Self.parseKey(fromFileName: fileName) else {
                    print("⚠️ Cannot parse TemplateKey from \(fileName)")
                    return
                }
                
                // 3️⃣ 生成灰度特征向量
                let grayVector = Self.makeGrayscaleVector(from: cg)
                
                // 4️⃣ 构造 TemplateDescriptor
                let desc = TemplateDescriptor(
                    key: key,
                    width: cg.width,
                    height: cg.height,
                    grayscaleVector: grayVector,
                    cgImage: cg
                )
                
                result[key] = desc
                print("✅ TemplateLoader: added template for key \(key)")
            }
        }
        
        print("✅ TemplateLoader: total \(result.count) templates loaded")
        return result
    }
    
    // MARK: - Parsing File Name
    
    /// 从文件名解析 TemplateKey。
    ///
    /// 例如：
    ///   blackBishop_blue_3840_2160.png
    ///   → namePart = blackBishop, backgroundPart = blue
    ///
    ///   empty_previous_3840_2160.png
    ///   → namePart = empty, backgroundPart = previous
    private static func parseKey(fromFileName fileName: String) -> TemplateKey? {
        let base = (fileName as NSString).deletingPathExtension
        
        // 按 '_' 切分：
        //   blackBishop_blue_3840_2160 → ["blackBishop", "blue", "3840", "2160"]
        //   empty_previous_3840_2160  → ["empty", "previous", "3840", "2160"]
        let parts = base.split(separator: "_")
        guard parts.count >= 2 else {
            print("⚠️ TemplateLoader: invalid file name format: \(fileName)")
            return nil
        }
        
        let namePart = String(parts[0])
        let backgroundPart = String(parts[1])
        
        // 1) 解析背景
        guard let background = BackgroundKind(from: backgroundPart) else {
            print("⚠️ TemplateLoader: invalid background token '\(backgroundPart)' in file \(fileName)")
            return nil
        }
        
        // 2) 解析棋子颜色 & 类型
        if namePart == "empty" {
            // 空格模板
            let key = TemplateKey(
                pieceColor: .none,
                pieceKind: .empty,
                background: background
            )
            return key
        } else if namePart.hasPrefix("white") {
            let pieceToken = String(namePart.dropFirst("white".count))
            guard let kind = PieceKind(fromPieceToken: pieceToken) else {
                print("⚠️ TemplateLoader: invalid piece token '\(pieceToken)' in file \(fileName)")
                return nil
            }
            let key = TemplateKey(
                pieceColor: .white,
                pieceKind: kind,
                background: background
            )
            return key
        } else if namePart.hasPrefix("black") {
            let pieceToken = String(namePart.dropFirst("black".count))
            guard let kind = PieceKind(fromPieceToken: pieceToken) else {
                print("⚠️ TemplateLoader: invalid piece token '\(pieceToken)' in file \(fileName)")
                return nil
            }
            let key = TemplateKey(
                pieceColor: .black,
                pieceKind: kind,
                background: background
            )
            return key
        } else {
            print("⚠️ TemplateLoader: cannot parse color/piece from '\(namePart)' in file \(fileName)")
            return nil
        }
    }
    
    // MARK: - Grayscale Feature
    
    /// 把 CGImage 压缩到小尺寸灰度图，并展开成 [Float] 方便做相似度比较。
    ///
    /// - 默认采样尺寸 sampleSize x sampleSize，例如 16x16 = 256 维。
    private static func makeGrayscaleVector(
        from image: CGImage,
        sampleSize: Int = 16
    ) -> [Float] {
        let width = sampleSize
        let height = sampleSize
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerPixel = 1
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: width * height)
        
        guard let ctx = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            print("⚠️ TemplateLoader: cannot create grayscale context")
            return []
        }
        
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 0...255 → 0.0...1.0
        let vector: [Float] = pixels.map { Float($0) / 255.0 }
        return vector
    }
}

// MARK: - Convenience initializers for enums

private extension BackgroundKind {
    init?(from raw: String) {
        switch raw.lowercased() {
        case "blue":
            self = .blue
        case "yellow":
            self = .yellow
        case "previous":
            self = .previous
        default:
            return nil
        }
    }
}

private extension PieceKind {
    /// 从文件名里剥离出来的棋子 token（不含颜色前缀）转成 PieceKind。
    ///
    /// 例如：
    ///   - "Pawn"   → .pawn
    ///   - "Knight" → .knight
    ///   - "Bishop" → .bishop
    ///   - "Rook"   → .rook
    ///   - "Queen"  → .queen
    ///   - "King"   → .king
    init?(fromPieceToken token: String) {
        switch token.lowercased() {
        case "pawn":
            self = .pawn
        case "knight":
            self = .knight
        case "bishop":
            self = .bishop
        case "rook":
            self = .rook
        case "queen":
            self = .queen
        case "king":
            self = .king
        default:
            return nil
        }
    }
}
