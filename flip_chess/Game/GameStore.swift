//
//  GameStore.swift
//  Flip Chess: Dark Xiangqi — 交互状态层
//
//  对应 ui.js 里那一大坨全局状态（state / stack / selected / moves / hint / busy / mode / level）。
//  全部收进一个 @MainActor 的 ObservableObject，UI 只读它。
//
//  ⚠️ 移植时的头号坑：ui.js 用 busy 标志 + setTimeout 把 AI 回合串行化。
//     Swift 里换成 async/await + @MainActor 保护 —— 玩家连点不可能插进 AI 的回合中间。
//

import Foundation
import SwiftUI

/// 对局模式
public enum GameMode: Sendable {
    case vsAI
    case twoPlayers

    public var isAI: Bool { self == .vsAI }
}

/// 棋盘上的一个覆盖标记（落点 / 最近一步 / 提示）
public struct BoardMark: Identifiable, Equatable {
    public enum Kind: Equatable { case move, capture, lastFrom, lastTo, hint }
    public let id = UUID()
    public var point: Point
    public var kind: Kind
}

/// 一次走子的动画状态。
///
/// 局面（GameState）在动画开始前就已经算完（值语义），这里只描述
/// 「棋盘现在该按什么样子画」—— 播完就丢掉，不参与任何规则判定。
public struct MoveAnimation: Equatable {

    /// 移动段的时长：明子只有这一段
    public static let moveSeconds: Double = 0.6
    /// 暗子「移动 + 翻开」的总时长
    public static let revealSeconds: Double = 1.0

    public var from: Point
    public var to: Point
    /// 起点棋子走之前的样子（暗子就是背面）
    public var mover: Piece?
    /// 被吃掉的棋子：停在终点，随移动进度淡出
    public var victim: Piece?
    /// 这一步是否让棋子翻开（暗子走完必翻开）
    public var didReveal: Bool
    /// 整段动画的进度 0..1（含翻面段）
    public var progress: Double = 0

    /// 整段时长
    public var duration: Double { didReveal ? Self.revealSeconds : Self.moveSeconds }

    /// 移动段占整段的比例：明子 = 1（整段都在移动）
    public var moveRatio: Double { didReveal ? Self.moveSeconds / Self.revealSeconds : 1 }

    /// 移动进度 0..1，带缓入缓出（滑到终点时慢下来）
    public var easedMove: Double {
        let t = min(1, max(0, progress / moveRatio))
        return t * t * (3 - 2 * t)
    }

    /// 翻面进度 0..1；这一步不需要翻面时为 nil
    public var flipProgress: Double? {
        guard didReveal else { return nil }
        return min(1, max(0, (progress - moveRatio) / (1 - moveRatio)))
    }

    /// 水平压扁系数：1 → 0.06 → 1（翻面就是「压扁 → 换面 → 展开」）
    public var flatten: Double {
        guard let f = flipProgress else { return 1 }
        let k = f < 0.5 ? f * 2 : (1 - f) * 2      // 0 → 1 → 0
        return 1 - k * 0.94
    }

    /// 当前该画哪一面：翻过一半（棋子最扁的那一刻）就换成翻开后的样子
    public var displayPiece: Piece? {
        guard var m = mover else { return nil }
        if let f = flipProgress, f >= 0.5 { m.isFaceUp = true }
        return m
    }
}

@MainActor
public final class GameStore: ObservableObject {

    // MARK: 对外只读状态

    @Published public private(set) var state: GameState
    @Published public private(set) var mode: GameMode = .vsAI
    @Published public private(set) var level: AILevel = .normal
    @Published public private(set) var selected: Point?
    @Published public private(set) var legalTargets: [Point] = []
    @Published public private(set) var hint: Action?
    /// 提示条文案（英文，海外版）
    @Published public private(set) var banner: String = ""
    /// 提示条配色
    @Published public private(set) var bannerTone: BannerTone = .normal
    @Published public private(set) var isBusy = false
    @Published public private(set) var canUndo = false
    /// 刚刚翻面的格子（用于播翻面动效；读后由 UI 自行清空）
    @Published public var revealAnimation: Point?
    /// 正在播的走子动画（nil = 没有动画；棋盘按 state 直接画）
    @Published public private(set) var moveAnimation: MoveAnimation?
    @Published public var result: ResultInfo?

    public enum BannerTone { case normal, warn, good }

    /// 本机玩家固定执红（与 Web 原型一致）
    public let mySide: Side = .red

    // MARK: 内部

    private var undoStack: [GameState] = []
    private var aiTask: Task<Void, Never>?
    private var bannerResetTask: Task<Void, Never>?
    private var animationTask: Task<Void, Never>?
    private var revealBurstTask: Task<Void, Never>?

    public struct ResultInfo: Identifiable, Equatable {
        public let id = UUID()
        public var title: String
        public var body: String
        public var didWin: Bool
        public var isDraw: Bool
    }

    public init() {
        state = GameState()
        refreshBanner()
    }

    // MARK: 开局 / 返回

    public func start(mode: GameMode, level: AILevel) {
        aiTask?.cancel()
        cancelAnimation()
        self.mode = mode
        self.level = level
        undoStack = []
        selected = nil
        legalTargets = []
        hint = nil
        isBusy = false
        result = nil
        revealAnimation = nil
        state = GameState()
        refreshUndo()
        flashBanner(diceRollText, tone: .good)
        scheduleAIIfNeeded()
    }

    private var diceRollText: String {
        "Dice roll: \(state.turn == .red ? "Red" : "Black") moves first"
    }

    // MARK: 点击棋盘

    /// 唯一的交互入口（对应 ui.js 的 onCell）。
    public func tap(_ p: Point) {
        guard !state.isOver, !isBusy else { return }
        if mode.isAI, state.turn != mySide { return }

        // 1) 点的是高亮落点 → 走子（暗子走完会自动翻开）
        if legalTargets.contains(p), let from = selected {
            performMove(from: from, to: p)
            return
        }

        guard let piece = state.piece(at: p) else {
            // 点空处 → 取消选择
            clearSelection()
            return
        }

        // 2) 点自己的明棋 → 选中 / 再点取消
        if piece.isFaceUp, piece.side == state.turn {
            toggleSelection(p)
            return
        }

        // 3) 点己方半场的暗子 → 选中，按「所在点位的标准棋子」亮出落点。
        //    落点绝不能按归属过滤：否则「有没有落点」会反过来泄露这枚暗子是谁的。
        if !piece.isFaceUp, Board.ownsHalf(state.turn, p.r) {
            toggleSelection(p)
            return
        }

        // 4) 对方半场的暗子 / 对方的明棋 → 拦下
        clearSelection()
        if !piece.isFaceUp {
            flashBanner("That hidden piece is in the opponent's half — you can only reveal it once it comes over",
                        tone: .warn)
        } else {
            flashBanner("That's the opponent's piece", tone: .warn)
        }
    }

    private func toggleSelection(_ p: Point) {
        if selected == p {
            clearSelection()
            return
        }
        selected = p
        // 刻意不按归属过滤落点（见上面第 3 点的说明）
        legalTargets = state.legalMoves(at: p)
        hint = nil
        SoundKit.shared.pick()
        refreshBanner()
    }

    private func clearSelection() {
        selected = nil
        legalTargets = []
        refreshBanner()
    }

    // MARK: 长按看英文

    /// 长按棋子的说明文案。**只讲公开信息**：
    /// 暗子只说「它按所在点位的哪种棋子走」，绝不透露真实归属，否则长按就成了作弊器。
    public func pieceInfo(at p: Point) -> String? {
        guard let piece = state.piece(at: p) else { return nil }
        if piece.isFaceUp {
            let sideText = piece.side == .red ? "Red" : "Black"
            let en = Board.englishName(piece.type)
            return "\(Board.displayName(piece)) · \(en)　(\(sideText) — face-up, moves as a normal \(en))"
        }
        let ht = Board.standardType(at: p) ?? .soldier
        let en = Board.englishName(ht)
        return "Face-down piece on a \(en) point — it moves like a \(en) while hidden, "
            + "and flips the moment it moves"
    }

    public func longPress(_ p: Point) {
        guard let text = pieceInfo(at: p) else { return }
        flashBanner(text, tone: .good)
    }

    // MARK: 行动

    private func performMove(from: Point, to: Point) {
        let mover = state.piece(at: from)
        let victim = state.piece(at: to)
        let willReveal = !(mover?.isFaceUp ?? true)
        SoundKit.shared.move(didCapture: victim != nil)

        undoStack.append(state)
        state = state.applying(Action(from: from, to: to))
        selected = nil
        legalTargets = []
        hint = nil
        refreshUndo()

        // 局面已经算完（值语义），棋盘先按「动画中的样子」画，播完才放开输入。
        // 暗子「移动 0.6s + 翻开 0.4s」共 1s；明子没有可翻的面，只有移动段 0.6s。
        animationTask?.cancel()
        revealBurstTask?.cancel()
        revealAnimation = nil
        isBusy = true
        let animation = MoveAnimation(from: from, to: to, mover: mover,
                                      victim: victim, didReveal: willReveal)
        moveAnimation = animation
        refreshBanner()

        animationTask = Task { [weak self] in
            let started = Date()
            while true {
                guard let self, !Task.isCancelled else { return }
                let t = Date().timeIntervalSince(started) / animation.duration
                self.moveAnimation?.progress = min(1, t)
                if t >= 1 { break }
                try? await Task.sleep(nanoseconds: 16_000_000)
                if Task.isCancelled { return }
            }
            guard let self, !Task.isCancelled else { return }
            self.moveAnimation = nil
            self.isBusy = false
            if willReveal { self.burstReveal(at: to) }
            self.refreshBanner()
            if self.state.isOver {
                self.finish()
            } else {
                self.scheduleAIIfNeeded()
            }
        }
    }

    /// 翻开完成：扩散环（0.42s 后自动收掉，不阻塞操作）
    private func burstReveal(at p: Point) {
        revealAnimation = p
        revealBurstTask?.cancel()
        revealBurstTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard let self, self.revealAnimation == p else { return }
            self.revealAnimation = nil
        }
    }

    /// 收掉正在播的走子动画（重开 / 认输时用）
    private func cancelAnimation() {
        animationTask?.cancel()
        animationTask = nil
        revealBurstTask?.cancel()
        revealBurstTask = nil
        moveAnimation = nil
        revealAnimation = nil
        isBusy = false
    }

    private func scheduleAIIfNeeded() {
        guard mode.isAI, state.turn != mySide, !state.isOver else { return }
        isBusy = true
        refreshBanner()
        aiTask?.cancel()
        let snapshot = state
        let lv = level
        aiTask = Task { [weak self] in
            // AI 是本地启发式（非云端），但 L3 是 2 层搜索，放后台跑避免卡住主线程
            let action = await Task.detached(priority: .userInitiated) {
                AI.choose(snapshot, for: snapshot.turn, level: lv)
            }.value
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.isBusy = false
            guard let action else { self.refreshBanner(); return }
            self.performMove(from: action.from, to: action.to)
        }
    }

    // MARK: 工具栏

    public func undo() {
        guard !isBusy, !state.isOver, !undoStack.isEmpty else { return }
        if mode.isAI {
            // 退回到最近一个「轮到我」的局面
            var idx = -1
            for i in stride(from: undoStack.count - 1, through: 0, by: -1)
            where undoStack[i].turn == mySide { idx = i; break }
            guard idx >= 0 else { return }
            state = undoStack[idx]
            undoStack = Array(undoStack.prefix(idx))
        } else {
            state = undoStack.removeLast()
        }
        selected = nil; legalTargets = []; hint = nil
        refreshUndo()
        refreshBanner()
    }

    public func showHint() {
        guard !isBusy, !state.isOver else { return }
        if mode.isAI, state.turn != mySide { return }
        guard let a = AI.choose(state, for: state.turn, level: .hard) else { return }
        hint = a
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard let self, self.hint == a else { return }
            self.hint = nil
        }
    }

    public func resign() {
        guard !state.isOver else { return }
        cancelAnimation()          // 动画中途认输：先收掉动画，免得它播完又收尾一次
        let loser = mode.isAI ? mySide : state.turn
        state = state.resigning(side: loser)
        selected = nil; legalTargets = []; hint = nil
        refreshBanner()
        finish()
    }

    private func finish() {
        guard let winner = state.winner else { return }
        let reason: String = {
            switch state.reason {
            case .king:   return "The General was captured."
            case .stuck:  return "The opponent has no legal move left."
            case .draw:   return "No capture and no flip for 60 moves each — a draw."
            case .resign: return "A player resigned."
            case .none:   return ""
            }
        }()

        switch (winner, mode) {
        case (.draw, _):
            result = ResultInfo(title: "Draw", body: reason, didWin: false, isDraw: true)
        case (.win(let side), .vsAI) where side == mySide:
            SoundKit.shared.win()
            result = ResultInfo(title: "You win", body: "You captured the enemy General. " + reason,
                                didWin: true, isDraw: false)
        case (.win, .vsAI):
            SoundKit.shared.lose()
            result = ResultInfo(title: "You lose", body: reason, didWin: false, isDraw: false)
        case (.win(let side), .twoPlayers):
            let name = side == .red ? "Red" : "Black"
            result = ResultInfo(title: "\(name) wins", body: reason, didWin: false, isDraw: false)
        }
    }

    // MARK: 提示条

    /// 未选中 / 选中 / 等待对手 的常驻文案
    public func refreshBanner() {
        if state.isOver { banner = "Game over"; bannerTone = .normal; return }
        if mode.isAI, state.turn != mySide { banner = "Opponent is thinking…"; bannerTone = .normal; return }
        let label = mode.isAI ? "Your turn" : (state.turn == .red ? "Red to move" : "Black to move")
        if let sel = selected {
            let piece = state.piece(at: sel)
            banner = label + ((piece?.isFaceUp ?? true)
                ? ": pick a destination. Tap an empty spot to cancel"
                : ": hidden piece — tap a destination to push it, and it flips as it moves. Tap it again to cancel")
            bannerTone = .normal
        } else {
            banner = label + ": tap one of your pieces to step it (hidden pieces move too, and flip after moving)"
            bannerTone = .normal
        }
    }

    /// 临时文案（1.7s 后回到常驻文案），对应 ui.js 的 flash
    public func flashBanner(_ text: String, tone: BannerTone = .normal) {
        banner = text
        bannerTone = tone
        bannerResetTask?.cancel()
        bannerResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            guard let self, !Task.isCancelled else { return }
            self.refreshBanner()
        }
    }

    private func refreshUndo() { canUndo = !undoStack.isEmpty && !state.isOver }

    // MARK: HUD 数据

    /// 「本方暗子 N」——按**半场**统计，不是按真实归属（否则会泄露情报）
    public func hiddenCount(for side: Side) -> Int { state.hiddenCount(inHalfOf: side) }

    public func capturedList(for side: Side) -> [CapturedPiece] { state.captured[side] ?? [] }

    public func opponentName() -> String { mode.isAI ? "Computer · \(levelName)" : "Black" }

    public var levelName: String {
        switch level {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }

    public var myName: String { mode.isAI ? "You · Red" : "Red" }
}
