//
//  EngineChecks.swift
//  Flip Chess: Dark Xiangqi — 规则引擎断言集
//
//  这是 docs/dark-chess/engine.test.js + ui.test.js 的 Swift 版：
//  写成**一份数据表**，XCTest 与命令行自检共用同一批断言，避免两处各写一套而走样。
//
//  每条 Check 的 run() 返回 nil 表示通过，返回字符串则是失败原因。
//

import Foundation

// 两种编译方式共用这一份断言表：
//   · 作为测试 target 的成员 → 需要显式引入被测模块
//   · 命令行自检（-D STANDALONE_CHECK，与 Engine/*.swift 同批编译）→ 同模块，不能写 import
#if !STANDALONE_CHECK
@testable import flip_chess
#endif

public struct Check {
    public let section: String
    public let name: String
    public let run: () -> String?
    public init(_ section: String, _ name: String, _ run: @escaping () -> String?) {
        self.section = section; self.name = name; self.run = run
    }
}

/// 断言辅助：相等 / 为真
private func eq<T: Equatable>(_ a: T, _ b: T, _ msg: String) -> String? {
    a == b ? nil : "\(msg)（期望 \(b)，实际 \(a)）"
}
private func ok(_ cond: Bool, _ msg: String) -> String? {
    cond ? nil : msg
}

/// 确定性随机源（Park-Miller），与 engine.js 的对拍脚本同构
public final class SeededRng {
    private var seed: Int
    public init(_ s: Int) { seed = s }
    public func next() -> Double {
        seed = (seed * 16807) % 2147483647
        return Double(seed) / 2147483647.0
    }
    public var closure: () -> Double { { self.next() } }
}

/// 造一个只放指定棋子的空局面，方便逐条验证走法
private func scene(turn: Side = .red, _ items: [(Point, Piece)]) -> GameState {
    var s = GameState(empty: ())
    s.turn = turn
    for (p, piece) in items { s.setPieceForAI(piece, at: p) }
    return s
}

private func P(_ r: Int, _ c: Int, _ s: Side, _ t: PieceType, up: Bool = true) -> (Point, Piece) {
    (Point(r, c), Piece(s, t, isFaceUp: up))
}

private func has(_ ps: [Point], _ r: Int, _ c: Int) -> Bool { ps.contains(Point(r, c)) }

public enum EngineChecks {

    public static func all() -> [Check] {
        var checks: [Check] = []
        func section(_ name: String, _ body: () -> [Check]) { checks += body().map {
            Check(name, $0.name, $0.run) } }

        // ═══════════ 1. 布阵 ═══════════
        section("布阵") { [
            Check("", "开局 32 枚棋子", {
                let s = GameState(rng: SeededRng(1).closure)
                let n = s.board.compactMap { $0 }.count
                return eq(n, 32, "棋子总数")
            }),
            Check("", "其中 30 枚扣着", {
                let s = GameState(rng: SeededRng(1).closure)
                let n = s.board.compactMap { $0 }.filter { !$0.isFaceUp }.count
                return eq(n, 30, "暗棋数")
            }),
            Check("", "恰好 2 枚明牌将帅", {
                let s = GameState(rng: SeededRng(1).closure)
                let n = s.board.compactMap { $0 }.filter { $0.type == .king && $0.isFaceUp }.count
                return eq(n, 2, "明牌将帅数")
            }),
            Check("", "红帅固定在 (9,4)、黑将固定在 (0,4)", {
                let s = GameState(rng: SeededRng(7).closure)
                guard let rk = s.king(of: .red), let bk = s.king(of: .black) else { return "找不到将帅" }
                return eq("\(rk.r),\(rk.c)/\(bk.r),\(bk.c)", "9,4/0,4", "将帅位置")
            }),
            Check("", "30 个暗棋点位的标准棋子构成 = 车4 马4 象4 士4 炮4 兵10", {
                // 这是「暗棋池」与「点位池」严丝合缝的关键：两边构成必须一致，
                // 否则会出现某种棋子永远摆在不符合它走法的点位上。
                var byType: [PieceType: Int] = [:]
                for entry in Board.darkPool { byType[entry.type, default: 0] += 1 }
                let got = "R\(byType[.chariot] ?? 0) H\(byType[.horse] ?? 0) E\(byType[.elephant] ?? 0) "
                    + "A\(byType[.advisor] ?? 0) C\(byType[.cannon] ?? 0) P\(byType[.soldier] ?? 0)"
                return eq(got, "R4 H4 E4 A4 C4 P10", "暗棋池构成")
            }),
            Check("", "标准 32 点去掉将帅两点 = 30 个暗棋点位", {
                return eq(Board.openSpots.count, 30, "暗棋点位数量")
            }),
            Check("", "每方 16 枚", {
                return eq(Board.sidePieces.count, 16, "每方子数")
            }),
        ] }

        // ═══════════ 2. 规则 3：暗棋按「所在点位的标准棋子」走 ═══════════
        section("规则3 暗棋按点位走") { [
            Check("", "底线车位上的暗子走法和车一样（真实身份无关）", {
                // 让它真实身份是 K/A/H/E/R/C/P 七种，落点必须完全一致
                var results: Set<String> = []
                for t in PieceType.allCases {
                    let s = scene([P(9, 0, .black, t, up: false)])   // (9,0) 是红方底线车位
                    let ms = s.legalMoves(at: Point(9, 0)).map { "\($0.r),\($0.c)" }.sorted()
                    results.insert(ms.joined(separator: "|"))
                }
                return eq(results.count, 1, "七种真实身份的落点应当完全一致（实际有 \(results.count) 种）")
            }),
            Check("", "空旷棋盘上 (9,0) 车位的暗子有 17 个落点", {
                let s = scene([P(9, 0, .black, .soldier, up: false)])
                let ms = s.legalMoves(at: Point(9, 0))
                return eq(ms.count, 17, "车位落点数（右 8 + 上 9）")
            }),
            Check("", "象位上的暗子只有 2 个落点（象走田，且被河界外的棋盘限制）", {
                let s = scene([P(9, 2, .black, .chariot, up: false)])
                let ms = s.legalMoves(at: Point(9, 2))
                return ok(ms.count <= 2, "象位落点数应 ≤2，实际 \(ms.count)")
            }),
            Check("", "兵位上的暗子只能向前一步", {
                let s = scene([P(6, 4, .black, .chariot, up: false)])   // 红方兵位
                let ms = s.legalMoves(at: Point(6, 4))
                return eq(ms.count, 1, "兵位落点数")
            }),
            Check("", "暗棋走法是「一次完整走法」，不是只能挪一格", {
                let s = scene([P(9, 0, .black, .chariot, up: false)])
                let ms = s.legalMoves(at: Point(9, 0))
                return ok(has(ms, 9, 5), "车位暗子应当能一路滑到 (9,5)，落点=\(ms.count)")
            }),
        ] }

        // ═══════════ 3. 规则 5/14/15：吃子判定（只用公开信息） ═══════════
        section("规则5 吃子") { [
            Check("", "暗棋可以吃对方半场的暗棋", {
                // (9,0) 是红方底线车位 → 红暗子按“车”的走法滑行；
                // (2,0) 落在黑方半场，因此是合法目标（不看它真实属于谁）。
                let s = scene(turn: .red, [
                    P(9, 0, .red, .soldier, up: false),
                    P(2, 0, .black, .chariot, up: false),
                ])
                let ms = s.legalMoves(at: Point(9, 0))
                return ok(has(ms, 2, 0), "应能吃 (2,0) 的暗棋，落点=\(ms.count)")
            }),
            Check("", "暗棋**不能**吃己方半场的暗棋（哪怕真实归属是对方）", {
                // (6,0) 是红方半场，放一枚**真实属于黑方**的暗棋；红方暗子与之相邻
                let s = scene(turn: .red, [
                    P(6, 2, .black, .soldier, up: false),  // 真实黑子，但站在红方兵位
                    P(6, 4, .red, .soldier, up: false),
                ])
                // (6,4) 兵位暗子只能往前 (5,4)，横走需过河
                let msA = s.legalMoves(at: Point(6, 4))
                return ok(!has(msA, 6, 2) && !has(msA, 6, 5), "兵位暗子不该横吃相邻格")
            }),
            Check("", "canLand：目标是明棋时只能吃对手的", {
                let s = scene(turn: .red, [P(5, 4, .red, .chariot)])
                let own = Piece(.red, .soldier, isFaceUp: true)
                let foe = Piece(.black, .soldier, isFaceUp: true)
                if s.canLand(own, mover: .red, to: Point(5, 5)) { return "不该能吃自家明棋" }
                if !s.canLand(foe, mover: .red, to: Point(5, 5)) { return "应能吃对方明棋" }
                return nil
            }),
            Check("", "canLand：目标是暗棋时只看「是否落在对方半场」", {
                let s = scene(turn: .red, [])
                let darkOwnHalf = Piece(.black, .soldier, isFaceUp: false)   // 真实黑子
                // 己方半场（红方 r>=5）里的暗棋：红方走子吃不到
                if s.canLand(darkOwnHalf, mover: .red, to: Point(6, 4)) { return "不该能吃自家阵地里的暗棋" }
                // 对方半场（r<=4）里的暗棋：可以吃，哪怕它真实是红子（自残）
                let darkFoeHalf = Piece(.red, .soldier, isFaceUp: false)
                if !s.canLand(darkFoeHalf, mover: .red, to: Point(2, 4)) { return "应能吃对方半场的暗棋（含自残）" }
                return nil
            }),
            Check("", "明棋不能吃自家阵地（己方半场）里的暗棋，但它照样挡路", {
                // 红车在 (9,0)，(7,0) 放一枚红方半场的暗棋
                let s = scene(turn: .red, [
                    P(9, 0, .red, .chariot),
                    P(7, 0, .black, .chariot, up: false),
                ])
                let ms = s.legalMoves(at: Point(9, 0))
                if has(ms, 7, 0) { return "不该能吃自家阵地里的暗棋" }
                if has(ms, 6, 0) || has(ms, 5, 0) { return "暗棋应当挡住车的去路" }
                return nil
            }),
        ] }

        // ═══════════ 4. 规则 6：暗棋走完必须翻开 ═══════════
        section("规则6 走完即翻") { [
            Check("", "暗棋走一步后立刻翻面", {
                let s = scene(turn: .red, [P(6, 4, .red, .cannon, up: false)])
                let next = s.applying(Action(from: Point(6, 4), to: Point(5, 4)))
                guard let p = next.piece(at: 5, 4) else { return "目标格没有棋子" }
                return ok(p.isFaceUp, "走完后应当是明棋")
            }),
            Check("", "翻开后回归传统象棋走法（不再按点位）", {
                // 红炮走到 (5,4) 后是明炮；再验证它按炮的走法（隔子打），而非 (5,4) 点位的兵走法
                let s = scene(turn: .red, [P(6, 4, .red, .cannon, up: false)])
                var next = s.applying(Action(from: Point(6, 4), to: Point(5, 4)))
                next.turn = .red
                let ms = next.legalMoves(at: Point(5, 4))
                // 明炮在空旷处走法同车：上下左右都能走
                return ok(has(ms, 5, 3) && has(ms, 0, 4), "明炮应当横向或纵向滑行，落点=\(ms.count)")
            }),
            Check("", "走明棋不会改变暗棋数量", {
                let s = scene(turn: .red, [P(9, 0, .red, .chariot), P(6, 4, .black, .soldier, up: false)])
                let before = s.hiddenCount(inHalfOf: .red)
                let next = s.applying(Action(from: Point(9, 0), to: Point(8, 0)))
                return eq(next.hiddenCount(inHalfOf: .red), before, "暗棋数")
            }),
        ] }

        // ═══════════ 5. 规则 10/11/12：区域与兵卒 ═══════════
        section("区域规则") { [
            Check("", "将/帅不能走出九宫", {
                let s = scene(turn: .red, [P(9, 4, .red, .king)])
                let ms = s.legalMoves(at: Point(9, 4))
                // 九宫是 r7..9, c3..5；从 (9,4) 只能走到 (8,4) (9,3) (9,5)
                let out = ms.map { "\($0.r),\($0.c)" }.sorted().joined(separator: "|")
                return eq(out, "8,4|9,3|9,5", "九宫内的落点")
            }),
            Check("", "仕/士不受区域限制，可以过河、可以进九宫", {
                let s = scene(turn: .red, [P(9, 3, .red, .advisor)])
                let ms = s.legalMoves(at: Point(9, 3))
                return ok(has(ms, 8, 2) && has(ms, 8, 4), "士应当能斜走到棋盘任意位置，落点=\(ms.count)")
            }),
            Check("", "相/象不受区域限制，可以过河", {
                // 红相在 (9,2)，走田到 (7,0) 与 (7,4)
                let s = scene(turn: .red, [P(9, 2, .red, .elephant)])
                let ms = s.legalMoves(at: Point(9, 2))
                return ok(has(ms, 7, 0) && has(ms, 7, 4), "象应当能走田，落点=\(ms.count)")
            }),
            Check("", "兵/卒未过河只能向前一步", {
                let s = scene(turn: .red, [P(6, 4, .red, .soldier)])
                let ms = s.legalMoves(at: Point(6, 4))
                return eq(ms.count, 1, "未过河兵落点数") ?? ok(has(ms, 5, 4), "应当只能走到 (5,4)")
            }),
            Check("", "兵/卒过河后可横走，但仍不能后退", {
                // 红兵推进到 (4,4)（已过河）
                let s = scene(turn: .red, [P(4, 4, .red, .soldier)])
                let ms = s.legalMoves(at: Point(4, 4))
                if !has(ms, 4, 3) || !has(ms, 4, 5) { return "过河兵应当能横走，落点=\(ms.count)" }
                if has(ms, 5, 4) { return "兵永远不能后退" }
                return ok(has(ms, 3, 4), "应当还能向前")
            }),
            Check("", "马腿被挡住时不能走", {
                let s = scene(turn: .red, [
                    P(5, 4, .red, .horse),
                    P(4, 4, .black, .soldier),   // 挡住马腿
                ])
                let ms = s.legalMoves(at: Point(5, 4))
                for m in ms {
                    if m.r <= 3 { return "被蹩腿的马不该能走到 \(m.r),\(m.c)" }
                }
                return nil
            }),
        ] }

        // ═══════════ 6. 炮：炮架明暗皆可、能打将 ═══════════
        section("炮") { [
            Check("", "炮架可以是暗棋", {
                let s = scene(turn: .red, [
                    P(9, 0, .red, .cannon),
                    P(4, 0, .black, .soldier, up: false),   // 暗棋当架
                    P(2, 0, .black, .chariot, up: false),   // 目标也是暗棋（黑方半场）
                ])
                let ms = s.legalMoves(at: Point(9, 0))
                return ok(has(ms, 2, 0), "应当能隔暗棋打到 (2,0)，落点=\(ms.count)")
            }),
            Check("", "炮能打到对方的将/帅", {
                let s = scene(turn: .black, [
                    P(0, 4, .red, .king),
                    P(3, 4, .black, .soldier, up: false),   // 炮架
                    P(6, 4, .black, .cannon, up: false),    // (6,4) 是红方兵位，标准类型是兵
                ])
                // 把 (6,4) 换成真正的炮：直接构造黑方明炮在 (7,4)
                var s2 = GameState(empty: ())
                s2.turn = .black
                s2.setPieceForAI(Piece(.red, .king, isFaceUp: true), at: Point(0, 4))
                s2.setPieceForAI(Piece(.black, .cannon, isFaceUp: true), at: Point(7, 4))
                s2.setPieceForAI(Piece(.black, .soldier, isFaceUp: true), at: Point(3, 4))
                let ms = s2.legalMoves(at: Point(7, 4))
                _ = s
                return ok(has(ms, 0, 4), "炮应当能隔着炮架打到 (0,4)，落点=\(ms.count)")
            }),
            Check("", "暗着的炮只可能在炮位上，打不到对方底线正中", {
                // (2,1) 是黑方炮位，它隔着 (1,1)…(0,1) 都打不到 (0,4)
                let s = scene(turn: .black, [P(2, 1, .black, .cannon, up: false)])
                let ms = s.legalMoves(at: Point(2, 1))
                return ok(!has(ms, 0, 4), "炮位上的暗炮不该能打到黑将自己的位置")
            }),
        ] }

        // ═══════════ 7. 终局 ═══════════
        section("终局") { [
            Check("", "吃掉将/帅即胜", {
                var s = GameState(empty: ())
                s.turn = .black
                s.setPieceForAI(Piece(.black, .chariot, isFaceUp: true), at: Point(1, 4))
                s.setPieceForAI(Piece(.red, .king, isFaceUp: true), at: Point(0, 4))
                s.setPieceForAI(Piece(.black, .king, isFaceUp: true), at: Point(0, 0))
                let next = s.applying(Action(from: Point(1, 4), to: Point(0, 4)))
                if !next.isOver { return "应当终局" }
                return eq(next.reason, EndReason.king, "终局原因")
            }),
            Check("", "困毙：无子可动即判负", {
                // 构造一个红方**确实**无子可动的局面（有将帅在场也不轻松，要卡准规则）：
                //   · 红将放在 (5,4) —— 不在己方九宫内，按规则 10 它一步都走不了
                //   · 红暗子在 (6,4) 兵位，唯一的前向格 (5,4) 被自家明将占住（兵不吃自家子）
                let s = scene(turn: .red, [
                    P(0, 4, .black, .king),
                    P(5, 4, .red, .king),
                    P(6, 4, .red, .soldier, up: false),
                ])
                let acts = s.allActions(for: .red)
                return ok(acts.isEmpty, "红方本应无子可动，实际有 \(acts.count) 个行动")
            }),
            Check("", "没有「原地翻开」这个动作", {
                let s = GameState(rng: SeededRng(3).closure)
                // 全部行动都必须落在不同格（即走一步），不存在原地不动的动作
                for a in s.allActions {
                    if a.from == a.to { return "出现了原地行动" }
                }
                return nil
            }),
            Check("", "己方半场被堵死的暗子一步都走不了", {
                let s = scene(turn: .red, [
                    P(6, 4, .red, .soldier, up: false),   // 兵位暗子，只能往前
                    P(5, 4, .red, .chariot, up: true),    // 堵住前面
                ])
                let ms = s.legalMoves(at: Point(6, 4))
                return ok(ms.isEmpty, "被堵死的暗子不该有落点，实际 \(ms.count) 个")
            }),
        ] }

        // ═══════════ 8. 可操作性（零泄露） ═══════════
        section("可操作性") { [
            Check("", "明棋只有自己的能动", {
                let s = scene(turn: .red, [P(5, 4, .black, .chariot)])
                return ok(!s.canPick(at: Point(5, 4), for: .red), "红方不该能操作黑方明棋")
            }),
            Check("", "暗棋只看点位：己方半场都能操作（不区分真实归属）", {
                var seed = 0
                var mismatches = 0
                for r in 0..<Board.rows where Board.ownsHalf(.red, r) {
                    for c in 0..<Board.cols {
                        seed += 1
                        // 同一点位分别放红暗子和黑暗子，可操作性必须一致
                        let a = scene(turn: .red, [P(r, c, .red, .soldier, up: false)])
                        let b = scene(turn: .red, [P(r, c, .black, .soldier, up: false)])
                        if a.canPick(at: Point(r, c), for: .red) != b.canPick(at: Point(r, c), for: .red) {
                            mismatches += 1
                        }
                    }
                }
                return eq(mismatches, 0, "「能不能操作」不该随真实归属变化")
            }),
            Check("", "对方半场的暗子不可操作", {
                let s = scene(turn: .red, [P(2, 4, .red, .soldier, up: false)])
                return ok(!s.canPick(at: Point(2, 4), for: .red), "红方不该能操作黑方半场的暗子")
            }),
        ] }

        // ═══════════ 9. AI ═══════════
        section("AI") { [
            Check("", "三档 AI 都能选出合法行动", {
                let s = GameState(rng: SeededRng(11).closure)
                for level in AILevel.allCases {
                    guard let a = AI.choose(s, for: s.turn, level: level, rng: SeededRng(5).closure) else {
                        return "L\(level.rawValue) 没选出行动"
                    }
                    if !s.legalMoves(at: a.from).contains(a.to) {
                        return "L\(level.rawValue) 选出了非法行动"
                    }
                }
                return nil
            }),
            Check("", "L1 有杀必杀", {
                var s = GameState(empty: ())
                s.turn = .black
                s.setPieceForAI(Piece(.black, .chariot, isFaceUp: true), at: Point(1, 4))
                s.setPieceForAI(Piece(.red, .king, isFaceUp: true), at: Point(0, 4))
                s.setPieceForAI(Piece(.black, .king, isFaceUp: true), at: Point(0, 0))
                s.setPieceForAI(Piece(.black, .chariot, isFaceUp: true), at: Point(9, 8))
                guard let a = AI.choose(s, for: .black, level: .easy, rng: SeededRng(1).closure) else {
                    return "没选出行动"
                }
                return eq("\(a.from.r),\(a.from.c)->\(a.to.r),\(a.to.c)", "1,4->0,4", "L1 应当直接吃将")
            }),
            Check("", "AI 不会偷看暗棋身份（同一局面的估值与真实归属无关）", {
                // 同一点位放红暗子或黑暗子，评估值必须相同
                var diffs = 0
                for (r, c) in [(2, 4), (6, 4), (4, 6)] {
                    let a = scene(turn: .red, [P(9, 0, .red, .chariot), P(r, c, .red, .chariot, up: false)])
                    let b = scene(turn: .red, [P(9, 0, .red, .chariot), P(r, c, .black, .chariot, up: false)])
                    if AI.evaluate(a, side: .red) != AI.evaluate(b, side: .red) { diffs += 1 }
                }
                return eq(diffs, 0, "估值不该随暗棋真实归属变化")
            }),
        ] }

        // ═══════════ 10. 海量对局（稳定性 + 斩首率守门） ═══════════
        section("对局统计") { [
            // 样本量刻意压到 40 局：模拟器里跑 200 局要 14 分钟，CI 无法接受。
            // 需要更大样本时跑命令行自检（见 docs/dark-chess/swift-verify/main.swift），
            // 那里在同一份断言上用 200 局做重活。
            Check("", "40 局 AI 自对弈全部正常收场", {
                var ended = 0
                for i in 0..<40 {
                    var s = GameState(rng: SeededRng(1000 + i).closure)
                    var ply = 0
                    while !s.isOver && ply < 600 {
                        guard let a = AI.choose(s, for: s.turn, level: .normal, rng: SeededRng(9000 + ply).closure) else {
                            break
                        }
                        s = s.applying(a)
                        ply += 1
                    }
                    if s.isOver { ended += 1 }
                }
                return ok(ended >= 38, "正常收场的对局偏少：\(ended)/40")
            }),
            Check("", "先手第一手斩首率 < 10%（规则已压住开局斩首）", {
                var kills = 0
                let N = 120
                for i in 0..<N {
                    let s = GameState(rng: SeededRng(3000 + i).closure)
                    guard let a = AI.choose(s, for: s.turn, level: .normal, rng: SeededRng(77).closure) else { continue }
                    if s.applying(a).isOver { kills += 1 }
                }
                let rate = Double(kills) / Double(N)
                return ok(rate < 0.10, "第一手斩首率 \(Int(rate * 100))%（应 <10%）")
            }),
        ] }

        return checks
    }

    /// 跑全部断言，返回 (通过数, 失败明细)
    public static func runAll(verbose: Bool = false) -> (passed: Int, failures: [String]) {
        let checks = all()
        var passed = 0
        var failures: [String] = []
        var lastSection = ""
        for c in checks {
            if c.section != lastSection && verbose {
                print("▶ \(c.section)")
                lastSection = c.section
            }
            if let reason = c.run() {
                failures.append("[\(c.section)] \(c.name)：\(reason)")
            } else {
                passed += 1
            }
        }
        return (passed, failures)
    }
}
