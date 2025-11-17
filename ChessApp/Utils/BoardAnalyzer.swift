
import Foundation
import AppKit
import CoreGraphics

/*
func generateFENFromCurrentBoard() {
    do {
        let fm = FileManager.default
        guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Cannot locate Documents directory")
            return
        }

        let boardURL = docsURL
            .appendingPathComponent("ChessApp")
            .appendingPathComponent("3840_2160")
            .appendingPathComponent("Board")
            .appendingPathComponent("1116_101450.png")

        guard fm.fileExists(atPath: boardURL.path) else {
            print("❌ Board image not found at path: \(boardURL.path)")
            return
        }

        print("📂 Board image = \(boardURL.path)")

        guard let nsImage = NSImage(contentsOf: boardURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Failed to load CGImage from \(boardURL.path)")
            return
        }

        // 2. 载入模板
        guard let resourcesURL = Bundle.main.resourceURL else {
            print("❌ Cannot locate Resources folder in app bundle")
            return
        }

        print("🔍 Templates folder = \(resourcesURL.path)")

        let templateLoader: TemplateLoaderProtocol = DefaultTemplateLoader()
        let templates = try templateLoader.loadTemplates(from: resourcesURL)
        print("✅ Loaded \(templates.count) templates")

        // 3. 切棋盘 8×8
        let sliceEngine = DefaultBoardSliceEngine()
        let squareImages = try sliceEngine.sliceBoard(from: cgImage, boardRect: nil)
        print("✅ Sliced board: ranks = \(squareImages.count), files = \(squareImages.first?.count ?? 0)")

        // 4. 分类出 BoardState
        let boardClassifier = DefaultBoardSquareClassifier()
        let boardState = try boardClassifier.classifyBoard(squareImages, using: templates)
        print("✅ Classified board into BoardState")
        print("   boardState.board.count = \(boardState.board.count)")
        if let firstRow = boardState.board.first {
            print("   boardState.board[0].count = \(firstRow.count)")
        }

        // 👉 多加一步打印，确认是否能走到这里
        print("➡️ About to encode FEN...")

        // 5. 编码 FEN
        let fenEncoder = DefaultFENEncoder()
        let fenString = try fenEncoder.encodePlacementOnly(from: boardState).value

        print("♟ FEN placement:")
        print(fenString)

    } catch {
        print("❌ Error generating FEN: \(error)")
    }
}
*/
/*
func generateFENFromCurrentBoard() {
    do {
        let fm = FileManager.default
        guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ Cannot locate Documents directory")
            return
        }

        let boardURL = docsURL
            .appendingPathComponent("ChessApp")
            .appendingPathComponent("3840_2160")
            .appendingPathComponent("Board")
            .appendingPathComponent("1116_101450.png")

        guard fm.fileExists(atPath: boardURL.path) else {
            print("❌ Board image not found at path: \(boardURL.path)")
            return
        }

        print("📂 Board image = \(boardURL.path)")

        guard let nsImage = NSImage(contentsOf: boardURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("❌ Failed to load CGImage from \(boardURL.path)")
            return
        }

        // 2. 模板路径（注意：不要再多加 “Resources” 目录）
        guard let resourcesURL = Bundle.main.resourceURL else {
            print("❌ Cannot locate Resources folder in app bundle")
            return
        }

        print("🔍 Templates folder = \(resourcesURL.path)")

        let templateLoader: TemplateLoaderProtocol = DefaultTemplateLoader()
        let templates = try templateLoader.loadTemplates(from: resourcesURL)
        print("✅ Loaded \(templates.count) templates")

        // 3. 切棋盘 8×8
        let sliceEngine = DefaultBoardSliceEngine()
        let squareImages = try sliceEngine.sliceBoard(from: cgImage, boardRect: nil)
        print("✅ Sliced board: ranks = \(squareImages.count), files = \(squareImages.first?.count ?? 0)")
        
        debugExportSquares(squareImages)
        // 4. 分类出 BoardState
        let boardClassifier = DefaultBoardSquareClassifier()
        let boardState = try boardClassifier.classifyBoard(squareImages, using: templates)
        print("✅ Classified board into BoardState")
        print("   boardState.board.count = \(boardState.board.count)")
        if let firstRow = boardState.board.first {
            print("   boardState.board[0].count = \(firstRow.count)")
        }

        print("➡️ About to encode FEN...")

        // 5. 编码 FEN（只输出布局）
        let fenEncoder = DefaultFENEncoder()
        let fenString = try fenEncoder.encodePlacementOnly(from: boardState).value

        print("♟ FEN placement:")
        print(fenString)

    } catch {
        print("❌ Error generating FEN: \(error)")
    }
}
*/
