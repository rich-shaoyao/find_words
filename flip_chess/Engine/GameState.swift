//
//  GameState.swift
//  Flip Chess: Dark Xiangqi — 单局状态与执行一步
//
//  对应 engine.js 的 newGame / clone / apply。
//  Swift 侧用**值语义**：applying() 返回全新状态，绝不改动传入值。
//

import Foundation

// MARK: - 行动 / 终局

/// 一个行动。本作**没有「原地翻开」**，所以 Action 只有「走一步」这一种形态
/// （engine.js 的 apply 里保留的 flip 分支在这里直接不存在）。
public struct Action: Hashable, Sendable {
    public var from: Point
    public var to: Point
    public init(from: Point, to: Point) { self.from = from; self.to = to }
}

/// 终局结果。对应 engine.js 里 winner 取 'r' / 'b' / 'draw' 三种值。
public enum Outcome: Equatable, Sendable {
    case win(Side)
    case draw
}

/// 终局原因。
public enum EndReason: String, Equatable, Sendable {
    case king   // 将/帅被吃
    case stuck  // 困毙：对方再无任何合法行动
    case draw   // 连续 120 个半步无吃子且无翻牌
    case resign // 认输
}

/// 最近一步，供 UI 高亮。
public struct LastMove: Equatable, Sendable {
    public var from: Point
    public var to: Point
    public var side: Side
    /// 被吃掉的棋子类型（空格为 nil）
    public var capturedType: PieceType?
    public var capturedSide: Side?
    /// 被吃时是否还扣着
    public var capturedWasFaceDown: Bool
    /// 这一步是否让某枚棋子翻面（决定和棋计时是否归零）
    public var didReveal: Bool
}

/// 被吃的棋子记录（HUD 的战利品栏用）。
public struct CapturedPiece: Equatable, Sendable {
    public var type: PieceType
    public var wasFaceUp: Bool
}

// MARK: - 局面

public struct GameState: Sendable {

    /// 一维棋盘，长度 90，索引 = r * 9 + c。nil 表示空点。
    public private(set) var board: [Piece?]
    /// 轮到谁走
    public var turn: Side
    /// 连续「无吃子且无翻牌」的半步数，用于判和
    public var quiet: Int
    /// 双方被吃掉的子（含明暗状态）
    public var captured: [Side: [CapturedPiece]]
    /// 最近一步
    public var last: LastMove?
    public var isOver: Bool
    public var winner: Outcome?
    public var reason: EndReason?

    // MARK: 访问

    public func piece(at p: Point) -> Piece? {
        guard Board.contains(p) else { return nil }
        return board[p.r * Board.cols + p.c]
    }

    public func piece(at r: Int, _ c: Int) -> Piece? {
        guard Board.contains(r, c) else { return nil }
        return board[r * Board.cols + c]
    }

    mutating func setPiece(_ piece: Piece?, at p: Point) {
        board[p.r * Board.cols + p.c] = piece
    }

    /// 找某方的将/帅
    public func king(of side: Side) -> Point? {
        for r in 0..<Board.rows {
            for c in 0..<Board.cols {
                if let p = board[r * Board.cols + c], p.side == side, p.type == .king {
                    return Point(r, c)
                }
            }
        }
        return nil
    }

    /// 统计某方的暗棋（按**真实归属**；UI 请改用 hiddenCount(inHalfOf:)）
    public func hiddenCount(of side: Side) -> Int {
        board.reduce(0) { acc, p in
            guard let p, !p.isFaceUp, p.side == side else { return acc }
            return acc + 1
        }
    }

    /// 统计「某方半场上还剩多少枚暗棋」—— 这是玩家真正能推的范围
    public func hiddenCount(inHalfOf side: Side) -> Int {
        var n = 0
        for r in 0..<Board.rows where Board.ownsHalf(side, r) {
            for c in 0..<Board.cols {
                if let p = board[r * Board.cols + c], !p.isFaceUp { n += 1 }
            }
        }
        return n
    }

    // MARK: 开局

    /// 布阵：将帅明牌固定在各自底线正中，其余 30 枚红黑混洗铺满 30 个暗棋点位。
    ///
    /// - Parameter rng: 0..<1 的随机源。传入确定性闭包即可让对局完全可复现（测试用）。
    public init(rng: () -> Double = { Double.random(in: 0..<1) }) {
        board = Array(repeating: nil, count: Board.cellCount)
        captured = [.red: [], .black: []]
        quiet = 0
        last = nil
        isOver = false
        winner = nil
        reason = nil
        turn = .red

        // 1) 将帅明牌，固定摆在各自主场的底线正中
        setPiece(Piece(.red, .king, isFaceUp: true), at: Board.kingHome[.red]!)
        setPiece(Piece(.black, .king, isFaceUp: true), at: Board.kingHome[.black]!)

        // 2) 30 枚暗棋混合洗牌，铺满其余 30 个标准点位（归属同样不确定）
        let pool = Self.shuffled(Board.darkPool, rng: rng)
        let spots = Self.shuffled(Board.openSpots, rng: rng)
        for i in 0..<pool.count {
            let entry = pool[i]
            setPiece(Piece(entry.side, entry.type, isFaceUp: false), at: spots[i])
        }

        // 先手随机：双方情报完全对称，红先并不构成优势
        turn = rng() < 0.5 ? .red : .black
    }

    /// 空棋盘（移植测试所需的构造入口；engine.js 里没有对应函数）
    public init(empty: Void) {
        board = Array(repeating: nil, count: Board.cellCount)
        captured = [.red: [], .black: []]
        quiet = 0
        last = nil
        isOver = false
        winner = nil
        reason = nil
        turn = .red
    }

    /// 与 engine.js 的 shuffle 完全同构（Fisher-Yates，从后往前），便于跨端对拍。
    static func shuffled<T>(_ arr: [T], rng: () -> Double) -> [T] {
        var a = arr
        if a.count < 2 { return a }
        for i in stride(from: a.count - 1, to: 0, by: -1) {
            let j = Int(rng() * Double(i + 1))
            a.swapAt(i, min(max(j, 0), i))
        }
        return a
    }

    // MARK: 执行一步

    /// 返回**新状态**；不改动 self（对应 engine.js 的 apply）。
    public func applying(_ a: Action) -> GameState {
        var s = self
        let moved = s.piece(at: a.from)
        let capturedPiece = s.piece(at: a.to)
        s.setPiece(moved, at: a.to)
        s.setPiece(nil, at: a.from)
        if let capturedPiece {
            s.captured[capturedPiece.side, default: []].append(
                CapturedPiece(type: capturedPiece.type, wasFaceUp: capturedPiece.isFaceUp))
        }

        // 规则 4：暗棋每走一步后，必须立即翻开、亮明身份
        var revealed = false
        if var m = moved, !m.isFaceUp {
            m.isFaceUp = true
            s.setPiece(m, at: a.to)
            revealed = true
        }

        s.last = LastMove(
            from: a.from, to: a.to, side: self.turn,
            capturedType: capturedPiece?.type,
            capturedSide: capturedPiece?.side,
            capturedWasFaceDown: capturedPiece.map { !$0.isFaceUp } ?? false,
            didReveal: revealed)

        // 吃掉将/帅 → 立刻终局
        if let capturedPiece, capturedPiece.type == .king {
            s.isOver = true
            s.winner = .win(moved?.side ?? self.turn)
            s.reason = .king
            s.turn = self.turn.opponent
            return s
        }

        // 和棋计时：只有「吃子」或「有棋子翻面」才算有进展
        s.quiet = revealed ? 0 : self.quiet + 1
        s.turn = self.turn.opponent

        // 终局判定：困毙（无任何合法行动）→ 该方负；双方各 60 手无进展 → 和
        if s.allActions(for: s.turn).isEmpty {
            s.isOver = true
            s.winner = .win(s.turn.opponent)
            s.reason = .stuck
        } else if s.quiet >= 120 {
            s.isOver = true
            s.winner = .draw
            s.reason = .draw
        }
        return s
    }

    /// 认输（UI 专用；engine.js 里由 ui.js 直接改状态，这里收进模型）
    public func resigning(side: Side) -> GameState {
        var s = self
        s.isOver = true
        s.winner = .win(side.opponent)
        s.reason = .resign
        return s
    }
}
