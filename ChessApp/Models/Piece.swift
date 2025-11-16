//
//  Piece.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

import Foundation
import CoreGraphics

enum PieceColor: String, Codable, Hashable {
    case white
    case black
    case none
}
enum PieceKind: String, Codable, Hashable {
    case pawn
    case knight
    case bishop
    case rook
    case queen
    case king
    case empty
}

enum BackgroundKind: String, Codable, Hashable {
    case blue       // dark square
    case yellow     // light square
    case previous   // highlight source/destination square
}

struct TemplateKey: Hashable, Codable {
    let pieceColor: PieceColor
    let pieceKind: PieceKind
    let background: BackgroundKind
}

/// Lightweight, safe template description.
/// No CGImage stored (to avoid CoreGraphics retain/release crashes on macOS).
struct TemplateDescriptor {
    let key: TemplateKey
    let width: Int          // preprocessed width (same as classifier)
    let height: Int         // preprocessed height
    let grayscaleVector: [Float]  // normalized [0, 1]
}
