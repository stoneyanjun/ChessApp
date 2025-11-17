//
//  FENString.swift
//  ChessApp
//
//  Created by stone on 2025/11/16.
//

// MARK: - Core Enums

/// 棋子颜色
enum PieceColor: String, Codable {
    case white
    case black
    case none   // 空格或未知
}

/// 棋子类型
enum PieceKind: String, Codable {
    case king
    case queen
    case rook
    case bishop
    case knight
    case pawn
    case empty  // 空格
}

/// 底色类型（棋盘背景），仅用于视觉/调试，不影响 FEN
enum BackgroundKind: String, Codable {
    case blue
    case yellow
    case previous  // 上一步走子涉及的格子
}

// MARK: - Template Key & Descriptor (用于模板匹配)

/// 模板的逻辑键，用于在模板字典中作为 key
struct TemplateKey: Hashable, Codable {
    let pieceColor: PieceColor
    let pieceKind: PieceKind
    let background: BackgroundKind
}

/// 一张模板图片的描述信息
struct TemplateDescriptor {
    let key: TemplateKey
    let width: Int
    let height: Int
    let grayscaleVector: [Float]   // 预处理后的灰度特征
}

// MARK: - SquareState & BoardState

/// 棋盘某一格的状态
struct SquareState: Codable {
    var pieceColor: PieceColor
    var pieceKind: PieceKind
    var background: BackgroundKind

    init(
        pieceColor: PieceColor = .none,
        pieceKind: PieceKind = .empty,
        background: BackgroundKind = .blue
    ) {
        self.pieceColor = pieceColor
        self.pieceKind = pieceKind
        self.background = background
    }

    /// 是否为空格（对 FEN 来说）
    var isEmptyForFEN: Bool {
        return pieceKind == .empty || pieceColor == .none
    }
}

/// 整个棋盘的抽象状态（8x8）。
///
/// 约定：
///   - board[rank][file]
///   - rank: 0 = 白方底线（1 排），7 = 黑方底线（8 排）
///   - file: 0 = a 列，7 = h 列
struct BoardState: Codable {

    /// 8x8 棋盘
    var board: [[SquareState]]

    /// 当前轮到谁走（可选，用于完整 FEN）
    var sideToMove: PieceColor

    /// 王车易位权利（例如 "KQkq"），这里仅占位，默认都可行
    var castlingRights: String

    /// en passant 目标格（例如 "e3"），这里默认 "-"
    var enPassantTarget: String

    /// 半步计数（double pawn push / capture 重置），默认 0
    var halfmoveClock: Int

    /// 全步数（从 1 开始），默认 1
    var fullmoveNumber: Int

    init() {
        // 默认构造一个 8x8 空棋盘
        let emptyRank = Array(repeating: SquareState(), count: 8)
        self.board = Array(repeating: emptyRank, count: 8)

        self.sideToMove = .white
        self.castlingRights = "KQkq"
        self.enPassantTarget = "-"
        self.halfmoveClock = 0
        self.fullmoveNumber = 1
    }
}
