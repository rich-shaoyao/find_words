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
    @Published public var result: ResultInfo?

    public enum BannerTone { case normal, warn, good }

    /// 本机玩家固定执红（与 Web 原型一致）
    public let mySide: Side = .red

    // MARK: 内部

    private var undoStack: [GameState] = []
    private var aiTask: Task<Void, Never>?
    private var bannerResetTask: Task<Void, Never>?

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
        let willReveal = !(mover?.isFaceUp ?? true)
        SoundKit.shared.move(didCapture: state.piece(at: to) != nil)

        undoStack.append(state)
        state = state.applying(Action(from: from, to: to))
        selected = nil
        legalTargets = []
        hint = nil
        refreshUndo()
        if willReveal {
            revealAnimation = to
            // 动效播完就清掉标记，避免棋盘上一直挂着扩散环
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 420_000_000)
                guard let self, self.revealAnimation == to else { return }
                self.revealAnimation = nil
            }
        }
        refreshBanner()

        if state.isOver {
            finish()
        } else {
            scheduleAIIfNeeded()
        }
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
