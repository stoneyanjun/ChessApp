//
//  ChessMove.swift
//  ChessApp
//
//  Created by stone on 2025/11/6.
//
struct ChessMove: Codable, Sendable, Equatable, Hashable {
    let from: Square
    let to: Square
    let promotion: String?

    init(from: Square, to: Square, promotion: String? = nil) {
        self.from = from
        self.to = to
        self.promotion = promotion
    }

    init?(uci: String) {
        let chars = Array(uci)
        guard chars.count >= 4 else { return nil }
        let promo = chars.count == 5 ? String(chars[4]) : nil
        guard let fromSquare = Square(file: chars[0], rank: chars[1]),
              let toSquare   = Square(file: chars[2], rank: chars[3]) else { return nil }
        self.from = fromSquare
        self.to = toSquare
        self.promotion = promo
    }

    var uci: String {
        if let promo = promotion { "\(from.uci)\(to.uci)\(promo)" }
        else { "\(from.uci)\(to.uci)" }
    }
}
