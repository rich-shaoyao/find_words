//
//  Rules.swift
//  Flip Chess: Dark Xiangqi — 走法生成与吃子判定
//
//  对应 engine.js 的 canLand / legalMoves / canPick / flippable / allActions。
//
//  ⚠️ 移植时的头号要点：**所有判定只依赖公开信息**（棋盘摆着什么、谁在走、
//     点位的标准归属），绝不使用暗棋的真实归属。否则玩家能从「能不能吃 / 能不能选」
//     反推出这枚暗子是谁的，破坏「归属不公开」这条支点规则。
//

import Foundation

extension GameState {

    // MARK: 吃子判定（规则 5 / 14 / 15）

    /// 吃子判定。原则：**只依赖公开信息**，绝不使用暗棋的真实归属。
    ///
    /// 明棋与暗棋用**同一套**判敌我标准：
    ///   · 目标是明棋：只能吃**移动方的对手**（明棋的归属本来就是公开的）
    ///   · 目标是暗棋：只能吃**位于对方半场**的暗棋（那一格的标准棋子本就属于对方）
    ///     → 所以明棋也**吃不了自家阵地里的暗棋**，哪怕那枚暗子的真实归属是对方。
    ///       「自残」仍然存在，但它只会发生在**对方半场**：明棋推进过去，吃到自家埋在敌阵里的子。
    ///
    /// - Parameters:
    ///   - target: 目标格上的棋子（空格传 nil）
    ///   - mover: 谁在走。判敌我的基准是「移动方」，不是暗棋的真实归属。
    ///   - to: 目标坐标（判断是否落在对方半场要用它）
    public func canLand(_ target: Piece?, mover: Side, to: Point) -> Bool {
        guard let target else { return true }              // 空格
        if target.isFaceUp { return target.side != mover } // 目标是明棋：只能吃对手的
        return !Board.ownsHalf(mover, to.r)                // 目标是暗棋：只能吃对方半场的
    }

    // MARK: 走法生成（规则 3 / 5 / 6 / 7 / 9）

    /// 一枚棋子的全部合法落点。
    ///
    ///   明棋：按它**真实的身份**走（规则 6）。
    ///   暗棋：按**它所在点位对应的标准象棋棋子**走（规则 3）—— 位置是公开的，
    ///         所以「选中暗棋看落点」不泄露任何情报。暗棋一移动就必须翻开，
    ///         因此它永远只站在标准点位上，standardType 永远取得到值。
    /// - Parameter mover: 判敌我的基准方。默认「当前行动方」，但**评估对手威胁时必须显式传对手**，
    ///   否则 canLand 会把对手的攻击当成自己的（引擎早期版本在此处埋过一个静默 bug）。
    public func legalMoves(at from: Point, mover explicitMover: Side? = nil) -> [Point] {
        guard let p = piece(at: from) else { return [] }
        let r = from.r, c = from.c
        var out: [Point] = []
        let mover = explicitMover ?? turn

        func push(_ tr: Int, _ tc: Int) {
            guard Board.contains(tr, tc) else { return }
            let to = Point(tr, tc)
            if canLand(piece(at: to), mover: mover, to: to) { out.append(to) }
        }

        // 走法依据的类型：明棋取真实身份，暗棋取所在点位的标准棋子
        let mt = p.isFaceUp ? p.type : (Board.standardType(at: from) ?? p.type)
        // 兵/卒的朝向：明棋看归属（它可能已经杀到对方半场），暗棋看它所在的半场
        let forward = (p.isFaceUp ? p.side == .red : r >= 5) ? -1 : 1

        switch mt {
        case .chariot:
            // 车：直线，路径须为空
            for d in Board.dirs4 {
                var tr = r + d.0, tc = c + d.1
                while Board.contains(tr, tc) {
                    let to = Point(tr, tc)
                    if let t = piece(at: to) {
                        if canLand(t, mover: mover, to: to) { out.append(to) }
                        break
                    }
                    out.append(to)
                    tr += d.0; tc += d.1
                }
            }

        case .cannon:
            // 炮：不吃子时走法同车；吃子须恰隔一个「炮架」。
            // 炮架**明暗皆可**（暗子也是棋盘上的实体），目标也可以是对方的**将/帅**。
            for d in Board.dirs4 {
                var tr = r + d.0, tc = c + d.1
                var jumped = false
                while Board.contains(tr, tc) {
                    let to = Point(tr, tc)
                    if let t = piece(at: to) {
                        if !jumped {
                            jumped = true                     // 明子暗子都能当架
                        } else {
                            if canLand(t, mover: mover, to: to) { out.append(to) }
                            break
                        }
                    } else if !jumped {
                        out.append(to)
                    }
                    tr += d.0; tc += d.1
                }
            }

        case .horse:
            // 马：走日，马腿有子（明暗皆算）则蹩
            for h in Board.horseSteps {
                let lr = r + h.legR, lc = c + h.legC
                guard Board.contains(lr, lc), piece(at: lr, lc) == nil else { continue }
                push(r + h.dr, c + h.dc)
            }

        case .elephant:
            // 相/象：走田，塞象眼；规则 11 特权：不受区域限制，可过河
            for d in Board.diag2 {
                let tr = r + d.0, tc = c + d.1
                guard Board.contains(tr, tc) else { continue }
                if piece(at: r + d.0 / 2, c + d.1 / 2) != nil { continue }   // 塞象眼
                push(tr, tc)
            }

        case .advisor:
            // 仕/士：斜一步；规则 11 特权：不受区域限制，可过河
            for d in Board.diag1 { push(r + d.0, c + d.1) }

        case .king:
            // 帅/将（规则 10）：直线一步，且必须落在己方九宫内
            for d in Board.dirs4 {
                let tr = r + d.0, tc = c + d.1
                guard Board.inPalace(p.side, tr, tc) else { continue }
                push(tr, tc)
            }

        case .soldier:
            // 兵/卒（规则 12）：未过河只能向前一步，过河后可左右平移，永不后退。
            // 过河按**实际所在行**判定（红兵 r<=4、黑卒 r>=5）。
            // 暗棋只可能站在己方兵/卒位上，所以暗着的兵/卒必定尚未过河。
            push(r + forward, c)
            let crossed = (forward == -1) ? (r <= 4) : (r >= 5)
            if crossed {
                push(r, c - 1)
                push(r, c + 1)
            }
        }

        // 传统象棋的「飞将」禁手：把会造成两将照面的落点整批剔除。
        // 放在最后统一过滤，车/炮那些直接 append 的分支也不会漏。
        guard let rk = palaceKing(of: .red), let bk = palaceKing(of: .black) else { return out }
        // 快速排除（绝大多数调用走这条）：两将不同列、且这一步动的不是将/帅
        // → 既不改变将的列、也不改变列上的遮挡，不可能造成照面。
        // 「是不是将/帅」只看公开信息（明牌 + 类型）；暗棋永远不可能站在将帅点位上，
        // 所以这里绝不碰暗棋的真实身份。
        if rk.c != bk.c && !(p.isFaceUp && p.type == .king) { return out }
        // 局面**本来就**照面（只可能出现在测试构造的非法局面里）时不再额外设限，
        // 否则会把这方的走法全禁掉、凭空判负。
        if kingsFace(rk, bk) { return out }
        return out.filter { !facesBetween(rk, bk, from: from, to: $0) }
    }

    /// 在九宫内找将/帅。将帅按规则只可能待在九宫里，所以这里只扫 9 格 ——
    /// 比全盘扫描便宜 10 倍，而 `legalMoves` 是 AI 搜索的热路径，这点差别很实在。
    /// 若某方将出了九宫（只可能是构造出来的非法局面），返回 nil，此时不施加飞将禁手。
    private func palaceKing(of side: Side) -> Point? {
        let rows = (side == .red) ? 7...9 : 0...2
        for r in rows {
            for c in 3...5 {
                if let p = piece(at: r, c), p.side == side, p.type == .king { return Point(r, c) }
            }
        }
        return nil
    }

    /// 两将**当前**是否照面（只看「格子有没有子」）
    private func kingsFace(_ redKing: Point?, _ blackKing: Point?) -> Bool {
        guard let rk = redKing, let bk = blackKing, rk.c == bk.c else { return false }
        for rr in (min(rk.r, bk.r) + 1)..<max(rk.r, bk.r) {
            if piece(at: rr, rk.c) != nil { return false }
        }
        return true
    }

    /// 传统象棋的「飞将」：走完 `from → to` 之后，双方将/帅是否在同一纵线上**照面**
    /// （同列，且两者之间一子也没有）。
    ///
    /// ⚠️ 九宫限制**并不**保证两将不同列 —— 红帅与黑将的九宫列都是 3–5：
    /// 红帅 (7,3) 对黑将 (0,3)、这条竖线上没子就是照面（旧说明里「二者永远无法照面」是错的）。
    /// 判定只看「格子有没有子」，与暗棋的真实身份无关，因此不泄露任何情报。
    private func facesBetween(_ redKing: Point?, _ blackKing: Point?,
                              from: Point, to: Point) -> Bool {
        guard let rk = redKing, let bk = blackKing else { return false }
        // 落点上正是一位将/帅 → 它被吃掉，棋盘上不再有它，也就不可能照面
        if to == rk || to == bk { return false }
        let r1 = (rk == from) ? to : rk          // 将/帅自己也会动
        let b1 = (bk == from) ? to : bk
        guard r1.c == b1.c else { return false }
        let col = r1.c
        for rr in (min(r1.r, b1.r) + 1)..<max(r1.r, b1.r) {
            if rr == from.r && from.c == col { continue }   // 这一格刚被腾空
            if rr == to.r && to.c == col { return false }   // 这一格刚落下棋子 → 挡住了
            if piece(at: rr, col) != nil { return false }   // 中间有子（明暗都算）
        }
        return true
    }

    // MARK: 可操作性

    /// 这枚棋子能不能被 `side` 操作？
    ///   明棋：只有自己的能动（归属本来就是公开信息）
    ///   暗棋：只看**点位**（是否落在己方半场），绝不看它的真实归属 ——
    ///         否则「能不能操作」会反过来泄露这枚暗子是谁的，也会和玩家侧的交互不对等。
    public func canPick(at p: Point, for side: Side) -> Bool {
        guard let piece = piece(at: p) else { return false }
        if piece.isFaceUp { return piece.side == side }
        return Board.ownsHalf(side, p.r)
    }

    /// 「己方半场上还剩哪些暗棋」。HUD 的「本方暗子 N」用；
    /// ⚠️ 它**不再是动作来源**（没有原地翻开），只用于计数与提示。
    public func hiddenPoints(inHalfOf side: Side) -> [Point] {
        var out: [Point] = []
        for r in 0..<Board.rows where Board.ownsHalf(side, r) {
            for c in 0..<Board.cols {
                let p = Point(r, c)
                if let piece = piece(at: p), !piece.isFaceUp { out.append(p) }
            }
        }
        return out
    }

    /// 某方全部合法行动。
    ///
    ///   ⚠️ 本作**没有「原地翻开」这个动作**：暗棋必须走一步，走完自动翻开（规则 6）。
    ///      所以己方半场里的某枚暗子若被彻底堵死、一步都走不了，它就永远翻不开，
    ///      会变成一堵永久的墙 —— 这是本规则已知且被接受的代价。
    public func allActions(for side: Side) -> [Action] {
        var acts: [Action] = []
        for r in 0..<Board.rows {
            for c in 0..<Board.cols {
                let from = Point(r, c)
                guard canPick(at: from, for: side) else { continue }
                for to in legalMoves(at: from) {
                    acts.append(Action(from: from, to: to))
                }
            }
        }
        return acts
    }

    /// 当前行动方的全部合法行动
    public var allActions: [Action] { allActions(for: turn) }

    /// 合法落点（当前行动方视角；UI 的落点高亮用）
    public func legalMovesForUI(at from: Point) -> [Point] {
        // 刻意**不按归属过滤**：否则「有没有落点」会反过来泄露这枚暗子是谁的
        legalMoves(at: from)
    }
}
