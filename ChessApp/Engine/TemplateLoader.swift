//
//  TemplateLoader.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation
import CoreGraphics
import ImageIO

/// Loads and prepares all template images (27 files) for later matching.
protocol TemplateLoaderProtocol {
    func loadTemplates(from rootURL: URL) throws -> [TemplateKey: TemplateDescriptor]
}

enum TemplateLoaderError: Error {
    case directoryNotFound(URL)
    case noPNGFilesFound(URL)
    case imageDecodeFailed(URL)
    case filenameParsingFailed(String)
    case preprocessingFailed(String)
}

/// Default implementation of TemplateLoaderProtocol for macOS.
final class DefaultTemplateLoader: TemplateLoaderProtocol {

    // Must match SquareClassifier
    private let targetWidth: Int = 64
    private let targetHeight: Int = 64

    func loadTemplates(from rootURL: URL) throws -> [TemplateKey: TemplateDescriptor] {
        print("🧩 TemplateLoader: rootURL = \(rootURL.path)")

        // 1. Verify directory exists
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: rootURL.path, isDirectory: &isDir),
              isDir.boolValue else {
            print("❌ TemplateLoader: directory not found")
            throw TemplateLoaderError.directoryNotFound(rootURL)
        }

        // 2. Enumerate *.png
        let contents = try fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let pngFiles = contents.filter { $0.pathExtension.lowercased() == "png" }
        print("🧩 TemplateLoader: found \(pngFiles.count) PNG files")

        guard !pngFiles.isEmpty else {
            throw TemplateLoaderError.noPNGFilesFound(rootURL)
        }

        var result: [TemplateKey: TemplateDescriptor] = [:]

        // 3. Process each file
        for url in pngFiles {
            try autoreleasepool {
                print("🧩 TemplateLoader: processing \(url.lastPathComponent)")

                let baseName = url.deletingPathExtension().lastPathComponent

                let key: TemplateKey
                do {
                    key = try parseTemplateKey(from: baseName)
                } catch {
                    print("❌ TemplateLoader: filenameParsingFailed for \(baseName)")
                    throw TemplateLoaderError.filenameParsingFailed(baseName)
                }

                // Load CGImage via ImageIO
                guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                      let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
                    print("❌ TemplateLoader: imageDecodeFailed for \(url.lastPathComponent)")
                    throw TemplateLoaderError.imageDecodeFailed(url)
                }

                let descriptor: TemplateDescriptor
                do {
                    descriptor = try makeDescriptor(from: cgImage, key: key)
                } catch {
                    print("❌ TemplateLoader: preprocessingFailed for \(baseName): \(error)")
                    throw TemplateLoaderError.preprocessingFailed("Failed for \(baseName): \(error)")
                }

                result[key] = descriptor
                print("✅ TemplateLoader: added template for key \(key)")
            }
        }

        print("✅ TemplateLoader: total \(result.count) templates loaded")
        return result
    }

    // MARK: - Filename parsing

    func parseTemplateKey(from baseName: String) throws -> TemplateKey {
        let parts = baseName.split(separator: "_").map(String.init)

        guard parts.count >= 2 else {
            throw TemplateLoaderError.filenameParsingFailed(baseName)
        }

        // Case 1: empty_* templates
        if parts[0].lowercased() == "empty" {
            let backgroundToken = parts[1].lowercased()
            let background: BackgroundKind

            switch backgroundToken {
            case "blue":
                background = .blue
            case "yellow":
                background = .yellow
            case "previous":
                background = .previous
            default:
                throw TemplateLoaderError.filenameParsingFailed(baseName)
            }

            return TemplateKey(
                pieceColor: .none,
                pieceKind: .empty,
                background: background
            )
        }

        // Case 2: normal piece: blackPawn_blue_3840_2160
        let token0 = parts[0]
        let pieceColor: PieceColor
        let pieceNamePart: String

        if token0.hasPrefix("white") {
            pieceColor = .white
            pieceNamePart = String(token0.dropFirst("white".count))
        } else if token0.hasPrefix("black") {
            pieceColor = .black
            pieceNamePart = String(token0.dropFirst("black".count))
        } else {
            throw TemplateLoaderError.filenameParsingFailed(baseName)
        }

        let pieceKind: PieceKind
        switch pieceNamePart.lowercased() {
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

        guard parts.count >= 2 else {
            throw TemplateLoaderError.filenameParsingFailed(baseName)
        }

        let bgToken = parts[1].lowercased()
        let background: BackgroundKind
        switch bgToken {
        case "blue":
            background = .blue
        case "yellow":
            background = .yellow
        case "previous":
            background = .previous
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

    func makeDescriptor(from image: CGImage, key: TemplateKey) throws -> TemplateDescriptor {
        let width = targetWidth
        let height = targetHeight
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw TemplateLoaderError.preprocessingFailed("Failed to create CGContext")
        }

        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        context.draw(image, in: rect)

        guard let data = context.data else {
            throw TemplateLoaderError.preprocessingFailed("No bitmap data")
        }

        let bytesPerRow = context.bytesPerRow
        let totalBytes = bytesPerRow * height
        let buffer = data.bindMemory(to: UInt8.self, capacity: totalBytes)

        var vector: [Float] = []
        vector.reserveCapacity(width * height)

        for y in 0..<height {
            let rowStart = y * bytesPerRow
            for x in 0..<width {
                let index = rowStart + x
                let v = Float(buffer[index]) / 255.0
                vector.append(v)
            }
        }

        return TemplateDescriptor(
            key: key,
            width: width,
            height: height,
            grayscaleVector: vector
        )
    }
}
