//
//  ChessBoardView.swift
//  ChessApp
//
//  Created by stone on 2025/11/6.
//
import SwiftUI

struct ChessBoardView: View {
    let board: ChessBoard
    let isFlipped: Bool
    let selectedSquare: Square?
    let highlightSquares: [Square]
    let onSelect: (Square) -> Void

    private let files = ["a","b","c","d","e","f","g","h"]

    var body: some View {
        let ranks = Array(1...8)
        let rankList = isFlipped ? ranks : ranks.reversed()
        let fileList = isFlipped ? files.reversed() : files

        VStack(spacing: 0) {
            ForEach(rankList, id: \.self) { rank in
                HStack(spacing: 0) {
                    ForEach(fileList, id: \.self) { file in
                        CellView(
                            file: file,
                            rank: rank,
                            board: board,
                            selectedSquare: selectedSquare,
                            highlightSquares: highlightSquares,
                            onSelect: onSelect
                        )
                    }
                }
            }
        }
        .border(Color.gray, width: 1)
    }
}

// MARK: - Extracted cell view to lighten type checking
private struct CellView: View {
    let file: String
    let rank: Int
    let board: ChessBoard
    let selectedSquare: Square?
    let highlightSquares: [Square]
    let onSelect: (Square) -> Void

    var body: some View {
        guard let square = Square("\(file)\(rank)") else {
            return AnyView(Color.clear.frame(width: 60, height: 60))
        }

        // ✅ Break heavy expression into small steps
        let fileValue: UInt8 = file.first?.asciiValue ?? 0
        let sum = rank + Int(fileValue)
        let isLight = (sum % 2 == 0)

        let piece = board.piece(at: square)
        let isHighlighted = highlightSquares.contains(square)
        let isSelected = selectedSquare == square

        let bgColor = isLight
            ? Color(red: 0.95, green: 0.93, blue: 0.80)
            : Color(red: 0.42, green: 0.56, blue: 0.74)

        return AnyView(
            ZStack {
                Rectangle().fill(bgColor)

                if isHighlighted {
                    Rectangle().strokeBorder(Color.yellow, lineWidth: 3)
                } else if isSelected {
                    Rectangle().strokeBorder(Color.orange, lineWidth: 3)
                }

                if let piece = piece {
                    Image(pieceImageName(for: piece))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .shadow(radius: 1.5)
                }
            }
            .frame(width: 60, height: 60)
            .onTapGesture { onSelect(square) }
        )
    }

    private func pieceImageName(for piece: Piece) -> String {
        switch (piece.color, piece.type) {
        case (.white, .pawn): return "whitePawn"
        case (.white, .rook): return "whiteCastle"
        case (.white, .knight): return "whiteKnight"
        case (.white, .bishop): return "whiteBishop"
        case (.white, .queen): return "whiteQueen"
        case (.white, .king): return "whiteKing"
        case (.black, .pawn): return "blackPawn"
        case (.black, .rook): return "blackCastle"
        case (.black, .knight): return "blackKnight"
        case (.black, .bishop): return "blackBishop"
        case (.black, .queen): return "blackQueen"
        case (.black, .king): return "blackKing"
        }
    }
}
