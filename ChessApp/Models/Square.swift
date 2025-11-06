//
//  Square.swift
//  ChessApp
//
//  Created by stone on 2025/11/6.
//

import Foundation

/// Represents a single square on the chessboard (e.g. "e4")
struct Square: Codable, Sendable, Equatable, Hashable {
    let file: Character   // 'a'–'h'
    let rank: Character   // '1'–'8'

    // MARK: - Initializers
    init?(file: Character, rank: Character) {
        guard "a"..."h" ~= file, "1"..."8" ~= rank else { return nil }
        self.file = file
        self.rank = rank
    }

    /// Convenience initializer from string like "e4"
    init?(uci: String) {
        guard uci.count == 2 else { return nil }
        let chars = Array(uci)
        self.init(file: chars[0], rank: chars[1])
    }

    /// Fallback alias (so Square("e4") also works)
    init?(_ rawValue: String) {
        self.init(uci: rawValue)
    }

    /// Convert to string ("e4")
    var uci: String { "\(file)\(rank)" }

    // MARK: - Codable
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let str = try container.decode(String.self)
        guard let square = Square(uci: str) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid square string: \(str)"
            )
        }
        self = square
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(uci)
    }
}

// MARK: - Convenience constants (optional, for readability)
extension Square {
    static let a1 = Square(file: "a", rank: "1")!
    static let b1 = Square(file: "b", rank: "1")!
    static let c1 = Square(file: "c", rank: "1")!
    static let d1 = Square(file: "d", rank: "1")!
    static let e1 = Square(file: "e", rank: "1")!
    static let f1 = Square(file: "f", rank: "1")!
    static let g1 = Square(file: "g", rank: "1")!
    static let h1 = Square(file: "h", rank: "1")!

    static let a8 = Square(file: "a", rank: "8")!
    static let b8 = Square(file: "b", rank: "8")!
    static let c8 = Square(file: "c", rank: "8")!
    static let d8 = Square(file: "d", rank: "8")!
    static let e8 = Square(file: "e", rank: "8")!
    static let f8 = Square(file: "f", rank: "8")!
    static let g8 = Square(file: "g", rank: "8")!
    static let h8 = Square(file: "h", rank: "8")!
}
