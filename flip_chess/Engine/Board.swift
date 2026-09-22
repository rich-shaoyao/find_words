//
//  Board.swift
//  Flip Chess: Dark Xiangqi — 棋盘坐标与静态表
//
//  与 docs/dark-chess/engine.js 逐条对照移植。坐标约定完全一致：
//    9 列(c: 0..8) × 10 行(r: 0..9)，棋子落在交叉点上
//    黑方半场 = 行 0..4（九宫 行 0..2，列 3..5）
//    红方半场 = 行 5..9（九宫 行 7..9，列 3..5）
//    河界在 行 4 与 行 5 之间
//
//  布阵（见 home / kingHome）：
//    1. 红帅固定 (9,4)、黑将固定 (0,4)，正面朝上 —— 全场仅此两枚明棋
//    2. 其余 30 枚（红 15 + 黑 15）全部背面朝上、混合洗牌后，
//       铺在中国象棋标准格局的其余 30 个点位上。
//       **每个点是哪个子、属于谁，全都不公开** —— 这是本玩法的核心。
//

import Foundation

// MARK: - 基础类型

/// 阵营。rawValue 与 engine.js 的 'r' / 'b' 一致，便于跨端对拍。
public enum Side: String, Codable, CaseIterable, Sendable {
    case red = "r"
    case black = "b"

    public var opponent: Side { self == .red ? .black : .red }
}

/// 棋子种类。rawValue 对应 engine.js 的 'K' / 'A' / 'E' / 'R' / 'H' / 'C' / 'P'。
public enum PieceType: String, Codable, CaseIterable, Sendable {
    case king = "K"
    case advisor = "A"
    case elephant = "E"
    case chariot = "R"
    case horse = "H"
    case cannon = "C"
    case soldier = "P"
}

/// 棋盘交叉点。
public struct Point: Hashable, Codable, Sendable {
    public var r: Int
    public var c: Int
    public init(_ r: Int, _ c: Int) { self.r = r; self.c = c }
}

/// 一枚棋子。
public struct Piece: Hashable, Codable, Sendable {
    public var side: Side
    public var type: PieceType
    /// 是否已经翻开（暗棋走完必须立刻翻开，见 GameState.applying）
    public var isFaceUp: Bool

    public init(_ side: Side, _ type: PieceType, isFaceUp: Bool) {
        self.side = side
        self.type = type
        self.isFaceUp = isFaceUp
    }
}

// MARK: - 棋盘几何与静态表

public enum Board {

    public static let rows = 10
    public static let cols = 9
    public static let cellCount = rows * cols

    public static func contains(_ r: Int, _ c: Int) -> Bool {
        r >= 0 && r < rows && c >= 0 && c < cols
    }

    public static func contains(_ p: Point) -> Bool { contains(p.r, p.c) }

    /// 是否落在某方的九宫内（3×3 田字格）。
    public static func inPalace(_ side: Side, _ r: Int, _ c: Int) -> Bool {
        switch side {
        case .red:   return r >= 7 && r <= 9 && c >= 3 && c <= 5
        case .black: return r >= 0 && r <= 2 && c >= 3 && c <= 5
        }
    }

    /// 该行是否属于 side 的半场。红 r>=5、黑 r<=4。
    /// 这是「能推哪些暗子」「暗棋能吃哪些目标」的唯一边界。
    public static func ownsHalf(_ side: Side, _ r: Int) -> Bool {
        side == .red ? r >= 5 : r <= 4
    }

    // MARK: 布阵

    /// 中国象棋的标准开局点位（每方 16 个）
    ///   红方：底线 9 点（r9,c0-8）+ 炮位 2 点（r7,c1/c7）+ 兵位 5 点（r6,c0/2/4/6/8）
    ///   黑方：底线 9 点（r0,c0-8）+ 炮位 2 点（r2,c1/c7）+ 卒位 5 点（r3,c0/2/4/6/8）
    public static let home: [Side: [Point]] = [
        .red: [
            Point(9, 0), Point(9, 1), Point(9, 2), Point(9, 3), Point(9, 4),
            Point(9, 5), Point(9, 6), Point(9, 7), Point(9, 8),
            Point(7, 1), Point(7, 7),
            Point(6, 0), Point(6, 2), Point(6, 4), Point(6, 6), Point(6, 8),
        ],
        .black: [
            Point(0, 0), Point(0, 1), Point(0, 2), Point(0, 3), Point(0, 4),
            Point(0, 5), Point(0, 6), Point(0, 7), Point(0, 8),
            Point(2, 1), Point(2, 7),
            Point(3, 0), Point(3, 2), Point(3, 4), Point(3, 6), Point(3, 8),
        ],
    ]

    /// 将/帅的固定位置：各自底线正中，正面朝上。
    public static let kingHome: [Side: Point] = [
        .red: Point(9, 4),
        .black: Point(0, 4),
    ]

    /// 「这个点位在中国象棋开局时站着的是什么棋子」—— 暗棋就按它走（规则 3）。
    /// 暗棋一移动就必须翻开，所以它永远只在标准点位上站过，这张表永远有定义。
    /// 30 个暗棋点位的类型构成恰为 车4 马4 象4 士4 炮4 兵10，与暗棋池完全一致。
    public static let homeType: [Point: PieceType] = {
        // 底线的九枚，从左到右
        let back: [PieceType] = [.chariot, .horse, .elephant, .advisor, .king,
                                 .advisor, .elephant, .horse, .chariot]
        var out: [Point: PieceType] = [:]
        for side in Side.allCases {
            let backRow = (side == .red) ? 9 : 0
            let cannonRow = (side == .red) ? 7 : 2
            for p in home[side]! {
                if p.r == backRow {
                    out[p] = back[p.c]
                } else if p.r == cannonRow {
                    out[p] = .cannon
                } else {
                    out[p] = .soldier
                }
            }
        }
        return out
    }()

    /// 取某点位对应的「标准棋子」类型；不是标准点位则返回 nil。
    /// 命名为 standardType 是为了不与上面的 homeType 表重名（表名沿用 engine.js 的叫法）。
    public static func standardType(at p: Point) -> PieceType? { homeType[p] }

    /// 标准 32 点里去掉被将帅占掉的 2 点 —— 剩下 30 个「暗棋点位」。长度恒为 30。
    public static let openSpots: [Point] = {
        var out: [Point] = []
        for side in Side.allCases {
            let kh = kingHome[side]!
            for p in home[side]! where p != kh { out.append(p) }
        }
        return out
    }()

    /// 每方 16 枚的构成：1 将/帅 + 2 仕 + 2 相 + 2 车 + 2 马 + 2 炮 + 5 兵。
    public static let sidePieces: [PieceType] = [
        .king,
        .advisor, .advisor,
        .elephant, .elephant,
        .chariot, .chariot,
        .horse, .horse,
        .cannon, .cannon,
        .soldier, .soldier, .soldier, .soldier, .soldier,
    ]

    /// 30 枚暗棋：红黑各 15 枚（不含将帅）。长度恒为 30。
    public static let darkPool: [(side: Side, type: PieceType)] = {
        var pool: [(side: Side, type: PieceType)] = []
        for side in Side.allCases {
            for t in sidePieces.dropFirst() { pool.append((side, t)) }
        }
        return pool
    }()

    // MARK: 方向向量（与 engine.js 的 DIRS4 / DIAG1 / DIAG2 / HORSE 逐项一致）

    /// 四方向：上、下、左、右
    public static let dirs4: [(Int, Int)] = [(-1, 0), (1, 0), (0, -1), (0, 1)]

    /// 斜一步（仕/士、以及象眼判定用）
    public static let diag1: [(Int, Int)] = [(-1, -1), (-1, 1), (1, -1), (1, 1)]

    /// 走田（相/象）
    public static let diag2: [(Int, Int)] = [(-2, -2), (-2, 2), (2, -2), (2, 2)]

    /// 马的走法：目标偏移 + 马腿偏移
    public struct HorseStep: Sendable {
        public let dr: Int
        public let dc: Int
        public let legR: Int
        public let legC: Int
    }

    /// 马走日的八个方向，顺序与 engine.js 的 HORSE 表一致
    public static let horseSteps: [HorseStep] = [
        HorseStep(dr: -2, dc: -1, legR: -1, legC: 0),
        HorseStep(dr: -2, dc: 1, legR: -1, legC: 0),
        HorseStep(dr: 2, dc: -1, legR: 1, legC: 0),
        HorseStep(dr: 2, dc: 1, legR: 1, legC: 0),
        HorseStep(dr: -1, dc: -2, legR: 0, legC: -1),
        HorseStep(dr: 1, dc: -2, legR: 0, legC: -1),
        HorseStep(dr: -1, dc: 2, legR: 0, legC: 1),
        HorseStep(dr: 1, dc: 2, legR: 0, legC: 1),
    ]

    // MARK: 棋子名称

    /// 棋子面的汉字。红黑各一套。
    public static let name: [PieceType: [Side: String]] = [
        .king:     [.red: "帅", .black: "将"],
        .advisor:  [.red: "仕", .black: "士"],
        .elephant: [.red: "相", .black: "象"],
        .chariot:  [.red: "车", .black: "车"],
        .horse:    [.red: "马", .black: "马"],
        .cannon:   [.red: "炮", .black: "炮"],
        .soldier:  [.red: "兵", .black: "卒"],
    ]

    /// 海外版英文名。棋子面**仍只画汉字**（国风视觉锚点，不被文字撑大）；
    /// 英文名不常驻盘面，改为**长按棋子**时弹出说明。采用国际通行的象棋译名。
    public static let nameEN: [PieceType: String] = [
        .king: "General", .advisor: "Advisor", .elephant: "Elephant",
        .chariot: "Chariot", .horse: "Horse", .cannon: "Cannon", .soldier: "Soldier",
    ]

    public static func displayName(_ piece: Piece) -> String {
        name[piece.type]?[piece.side] ?? "?"
    }

    public static func englishName(_ type: PieceType) -> String {
        nameEN[type] ?? "piece"
    }

    /// 子力价值（AI 评估用）
    public static let value: [PieceType: Double] = [
        .king: 1000, .chariot: 9, .cannon: 4.5, .horse: 4,
        .advisor: 2, .elephant: 2, .soldier: 1,
    ]
}
