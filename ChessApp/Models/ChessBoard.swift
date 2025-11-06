//
//  ChessBoard.swift
//  ChessApp
//
//  Created by stone on 2025/11/4.
//

import Foundation

/// Type of chess piece
enum PieceType: String, Codable, Sendable, CaseIterable {
    case pawn
    case knight
    case bishop
    case rook
    case queen
    case king
}

struct Piece: Codable, Sendable, Equatable {
    var type: PieceType
    var color: PieceColor

    init(_ type: PieceType, _ color: PieceColor) {
        self.type = type
        self.color = color 
    }

    var symbol: String {
        switch (color, type) {
        case (.white, .pawn): return "♙"
        case (.white, .rook): return "♖"
        case (.white, .knight): return "♘"
        case (.white, .bishop): return "♗"
        case (.white, .queen): return "♕"
        case (.white, .king): return "♔"
        case (.black, .pawn): return "♟"
        case (.black, .rook): return "♜"
        case (.black, .knight): return "♞"
        case (.black, .bishop): return "♝"
        case (.black, .queen): return "♛"
        case (.black, .king): return "♚"
        }
    }
}

enum PieceColor: String, Codable, Sendable, CaseIterable {
    case white, black
}

struct ChessBoard: Codable, Sendable, Equatable {
    // 8×8 grid mapping from Square → Piece (or empty)
    private var pieces: [Square: Piece]

    // Whose turn (white/black)
    var whiteToMove: Bool

    // Castling, en passant, halfmove, fullmove (for FEN)
    var castlingRights: String
    var enPassantTarget: Square?
    var halfmoveClock: Int
    var fullmoveNumber: Int

    // MARK: - Initialization
    init(
        pieces: [Square: Piece],
        whiteToMove: Bool = true,
        castlingRights: String = "KQkq",
        enPassantTarget: Square? = nil,
        halfmoveClock: Int = 0,
        fullmoveNumber: Int = 1
    ) {
        self.pieces = pieces
        self.whiteToMove = whiteToMove
        self.castlingRights = castlingRights
        self.enPassantTarget = enPassantTarget
        self.halfmoveClock = halfmoveClock
        self.fullmoveNumber = fullmoveNumber
    }

    /// Factory: standard starting position
    static func initial() -> ChessBoard {
        var board: [Square: Piece] = [:]

        // White pieces
        board[.a1] = Piece(.rook, .white)
        board[.b1] = Piece(.knight, .white)
        board[.c1] = Piece(.bishop, .white)
        board[.d1] = Piece(.queen, .white)
        board[.e1] = Piece(.king, .white)
        board[.f1] = Piece(.bishop, .white)
        board[.g1] = Piece(.knight, .white)
        board[.h1] = Piece(.rook, .white)
        for file in ["a","b","c","d","e","f","g","h"] {
            board[Square("\(file)2")!] = Piece(.pawn, .white)
        }

        // Black pieces
        board[.a8] = Piece(.rook, .black)
        board[.b8] = Piece(.knight, .black)
        board[.c8] = Piece(.bishop, .black)
        board[.d8] = Piece(.queen, .black)
        board[.e8] = Piece(.king, .black)
        board[.f8] = Piece(.bishop, .black)
        board[.g8] = Piece(.knight, .black)
        board[.h8] = Piece(.rook, .black)
        for file in ["a","b","c","d","e","f","g","h"] {
            board[Square("\(file)7")!] = Piece(.pawn, .black)
        }

        return ChessBoard(pieces: board)
    }
}

extension ChessBoard {
    /// Apply a simple move on the board (Phase-1: no legality checks yet)
    mutating func applyMove(_ move: ChessMove) {
        guard let movingPiece = pieces[move.from] else { return }

        // remove captured piece if any
        pieces[move.to] = nil

        // promotion
        if let promo = move.promotion, movingPiece.type == .pawn {
            if let promoType = PieceType(rawValue: promo) {
                pieces[move.to] = Piece(promoType, movingPiece.color)
            } else {
                // fallback if engine sends 'q' instead of "queen"
                let mapped: PieceType?
                switch promo.lowercased() {
                case "q": mapped = .queen
                case "r": mapped = .rook
                case "b": mapped = .bishop
                case "n": mapped = .knight
                default:  mapped = nil
                }
                if let mapped {
                    pieces[move.to] = Piece(mapped, movingPiece.color)
                }
            }
        }

        pieces[move.from] = nil
        whiteToMove.toggle()
    }

    /// Convert the board into a FEN string for Stockfish
    func fen() -> String {
        var fen = ""
        for rank in (1...8).reversed() {
            var empty = 0
            for file in ["a","b","c","d","e","f","g","h"] {
                let square = Square("\(file)\(rank)")!
                if let piece = pieces[square] {
                    if empty > 0 { fen += "\(empty)"; empty = 0 }
                    fen += piece.color == .white
                        ? piece.type.rawValue.uppercased()
                        : piece.type.rawValue.lowercased()
                } else {
                    empty += 1
                }
            }
            if empty > 0 { fen += "\(empty)" }
            if rank > 1 { fen += "/" }
        }
        fen += whiteToMove ? " w " : " b "
        fen += "\(castlingRights) "
        fen += enPassantTarget?.uci ?? "-"
        fen += " \(halfmoveClock) \(fullmoveNumber)"
        return fen
    }
}
extension ChessBoard {
    /// Returns the piece located at the given square (if any)
    func piece(at square: Square) -> Piece? {
        return pieces[square]
    }
}
