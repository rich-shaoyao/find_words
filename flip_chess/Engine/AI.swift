//
//  AI.swift
//  Flip Chess: Dark Xiangqi — 三档 AI 与局面评估
//
//  对应 engine.js 的 kingDanger / advance / evaluate / actionScore / aiChoose。
//
//  调参记录（来自 Web 原型实测，200 局 L2 镜像）：
//    · advance 权重 0.06 → 和棋 87%
//    · advance 权重 0.18 → 和棋 39%   ← 采用
//    · 盲走暗棋惩罚 -0.8 → 和棋 90.5%；改成 -0.15 后降到 38.5%
//    这两个数值是标定出来的，改动前请重跑对局统计。
//

import Foundation

/// 难度档位
public enum AILevel: Int, CaseIterable, Sendable {
    case easy = 1    // 能杀就杀，否则随机
    case normal = 2  // 贪心评估
    case hard = 3    // 贪心 + 对手最佳反击一手
}

public enum AI {

    // MARK: 局面评估

    /// 己方将/帅在「一步之内」被对方**明棋**瞄准的总威胁。
    /// 只算明棋：暗棋的身份双方都看不见，AI 不该拿它当已知情报。
    static func kingDanger(_ s: GameState, side: Side) -> Double {
        guard let k = s.king(of: side) else { return 0 }
        let enemy = side.opponent
        var danger = 0.0
        for r in 0..<Board.rows {
            for c in 0..<Board.cols {
                guard let p = s.piece(at: r, c), p.isFaceUp, p.side == enemy else { continue }
                // 关键：以**敌人**为移动方生成走法，否则 canLand 判敌我会用错基准
                let ms = s.legalMoves(at: Point(r, c), mover: enemy)
                if ms.contains(k) {
                    danger += (Board.value[p.type] ?? 1) * 0.7
                }
            }
        }
        return danger
    }

    /// 「推进度」：己方明棋离对方将/帅越近，越有形成实际威胁的可能。
    /// 斩首必须先把棋子压到九宫附近，没有这一项 AI 会一直原地倒子（取消原地翻开后尤其明显）。
    static func advance(_ s: GameState, side: Side) -> Double {
        guard let kOpp = s.king(of: side.opponent) else { return 0 }
        var sum = 0.0
        for r in 0..<Board.rows {
            for c in 0..<Board.cols {
                guard let p = s.piece(at: r, c), p.isFaceUp, p.side == side, p.type != .king else { continue }
                let dist = abs(r - kOpp.r) + abs(c - kOpp.c)
                sum += (18 - Double(min(dist, 18))) * 0.18
            }
        }
        return sum
    }

    /// 暗棋是红黑混装、归属未知，对双方的期望贡献相抵，因此只评估明棋。
    public static func evaluate(_ s: GameState, side: Side) -> Double {
        var score = 0.0
        for r in 0..<Board.rows {
            for c in 0..<Board.cols {
                guard let p = s.piece(at: r, c), p.isFaceUp else { continue }
                var v = Board.value[p.type] ?? 1
                // 兵/卒过河后价值提升
                if p.type == .soldier {
                    let crossed = (p.side == .red) ? (r <= 4) : (r >= 5)
                    if crossed { v = 2.2 }
                }
                score += (p.side == side ? v : -v)
            }
        }
        // 老将的安全：被对方明棋瞄准要扣分，瞄准对方要加分
        score -= kingDanger(s, side: side)
        score += kingDanger(s, side: side.opponent)
        // 推进度：把子力往对方九宫压
        score += advance(s, side: side) - advance(s, side: side.opponent)
        return score
    }

    /// 一步棋的增量价值。
    static func actionScore(_ s: GameState, _ a: Action, side: Side) -> Double {
        var next = s.applying(a)
        let mover = s.piece(at: a.from)
        let blind = !(mover?.isFaceUp ?? true)     // 这一步是「盲走暗棋」

        // 盲走时不让 AI 偷看翻出来的身份：把目标格的棋子按「仍然扣着」来估值
        // （暗棋对双方的期望价值相抵），否则 AI 会用人类不可能拥有的情报挑最优的那枚
        if blind, var m = next.piece(at: a.to) {
            m.isFaceUp = false
            next.setPieceForAI(m, at: a.to)
        }

        var sc = evaluate(next, side: side) - evaluate(s, side: side)

        if let t = s.piece(at: a.to) {
            // 直接吃掉对方的将/帅
            if t.type == .king, t.side != side { return 1e6 }
            if !t.isFaceUp {
                sc += (Board.value[t.type] ?? 1) * 0.5 + 1      // 吃暗棋：一半概率是对方的，也是探路
            } else if t.side != side {
                sc += (Board.value[t.type] ?? 1) * 0.6 + 1.5
            } else {
                sc -= (Board.value[t.type] ?? 1) * 0.8          // 自残
            }
        }

        // 盲走暗棋的代价：走完即暴露，还可能替对手推了一步。
        // 但不能罚太重 —— 取消「原地翻开」之后，「推暗子」是**唯一**的揭面手段，
        // 罚狠了 AI 就会一直倒明子、把局面拖成 90% 和棋。推出去也算拿到情报，所以只留一点点代价。
        if blind { sc -= 0.15 }
        return sc
    }

    // MARK: 选择

    /// 选一步棋。无合法行动时返回 nil。
    ///
    /// - Parameter rng: 0..<1 随机源。L1/L2 都要用它（L1 随机、L2 加噪声避免每局同解）。
    public static func choose(_ s: GameState, for side: Side,
                              level: AILevel = .normal,
                              rng: () -> Double = { Double.random(in: 0..<1) }) -> Action? {
        let acts = s.allActions(for: side)
        guard !acts.isEmpty else { return nil }

        if level == .easy {
            // 入门：能杀就杀，否则随机
            for a in acts {
                if let t = s.piece(at: a.to), t.type == .king, t.side != side { return a }
            }
            return acts[min(Int(rng() * Double(acts.count)), acts.count - 1)]
        }

        var best: Action?
        var bestScore = -Double.infinity
        for a in acts {
            var sc = actionScore(s, a, side: side)
            if level == .hard {
                // 困难：再看对手最佳反击一手
                let nx = s.applying(a)
                if !nx.isOver {
                    let reps = nx.allActions(for: nx.turn)
                    var worst = 0.0
                    for r in reps {
                        let rs = actionScore(nx, r, side: nx.turn)
                        if rs > worst { worst = rs }
                    }
                    sc -= worst * 0.85
                }
            }
            sc += rng() * 0.05                 // 加入噪声，避免每局完全同解
            if sc > bestScore { bestScore = sc; best = a }
        }
        return best
    }
}

extension GameState {
    /// AI 内部用：把某格棋子替换为「仍扣着」的副本（估值时屏蔽真实身份）
    mutating func setPieceForAI(_ piece: Piece?, at p: Point) {
        setPiece(piece, at: p)
    }
}
