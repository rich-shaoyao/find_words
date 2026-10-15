//
//  EngineTests.swift
//  Flip Chess: Dark Xiangqi — XCTest 入口
//
//  真正的断言写在 EngineChecks.swift 的检查表里，这里只做「跑一遍表」。
//  这样做的好处：同一批断言既能被 XCTest 跑（Xcode / CI），
//  也能被命令行自检跑（见 docs/dark-chess/swift-verify/main.swift），
//  两边永远不可能走样成两套标准。
//

import XCTest
@testable import flip_chess

final class DarkChessEngineTests: XCTestCase {

    /// 全量断言：布阵 / 规则3 / 规则5 / 规则6 / 区域 / 炮 / 终局 / 可操作性 / AI / 对局统计
    func testAllEngineChecks() {
        let (passed, failures) = EngineChecks.runAll(verbose: true)
        XCTAssertTrue(failures.isEmpty,
                      "\(failures.count) 项断言失败：\n" + failures.joined(separator: "\n"))
        XCTAssertGreaterThan(passed, 30, "断言数量异常偏少，检查表可能没被加载")
    }

    /// 跨端基线：确定性 RNG 下的开局必须与 engine.js 完全一致。
    /// 基线值由 docs/dark-chess/swift-verify/opening-baseline.js 产出。
    func testOpeningMatchesJSEngine() {
        let s = GameState(rng: SeededRng(12345).closure)

        let pieces = s.board.compactMap { $0 }.count
        XCTAssertEqual(pieces, 32, "棋子总数应为 32")

        let hidden = s.board.compactMap { $0 }.filter { !$0.isFaceUp }.count
        XCTAssertEqual(hidden, 30, "暗棋应为 30 枚")

        let faceUpKings = s.board.compactMap { $0 }.filter { $0.type == .king && $0.isFaceUp }.count
        XCTAssertEqual(faceUpKings, 2, "明牌将帅应为 2 枚")

        XCTAssertEqual(s.king(of: .red), Point(9, 4), "红帅固定底线正中")
        XCTAssertEqual(s.king(of: .black), Point(0, 4), "黑将固定底线正中")

        // 逐格基线（与 opening-baseline.js 的 board= 行同一串）
        // 前 26 格与 opening-baseline.js 的 board= 行逐字符对齐（该行共 90 格，这里只比前 26 格）
        let expected = "Cr0,Eb0,Rb0,Cr0,Kb1,Rb0,Rr0,Pr0,Ab0,...,...,...,...,...,...,...,...,...,...,"
            + "Ar0,...,...,...,...,...,Pb0"
        var cells: [String] = []
        for r in 0..<Board.rows {
            for c in 0..<Board.cols {
                if let p = s.piece(at: r, c) {
                    cells.append("\(p.type.rawValue)\(p.side.rawValue)\(p.isFaceUp ? "1" : "0")")
                } else { cells.append("...") }
            }
        }
        XCTAssertEqual(cells.prefix(26).joined(separator: ","), expected,
                       "开局前 26 格必须与 engine.js 逐格一致")
    }
}

/// 走子动画的时间线：暗子 = 移动 0.6s + 原地翻开 0.4s（共 1s）；明子只有移动段 0.6s。
/// 这套式子与原型 ui.js 的 animState() 同构（ui.test.js 里有对应断言）。
final class MoveAnimationTests: XCTestCase {

    private func piece(faceUp: Bool) -> Piece { Piece(.red, .chariot, isFaceUp: faceUp) }

    func testHiddenPieceTimeline() {
        var a = MoveAnimation(from: Point(9, 0), to: Point(8, 0),
                              mover: piece(faceUp: false), victim: nil, didReveal: true)
        XCTAssertEqual(a.duration, 1.0, accuracy: 1e-9, "暗子是「移动 + 翻开」共 1 秒")

        // 起步：还在起点，也没开始翻面
        XCTAssertEqual(a.easedMove, 0, accuracy: 1e-9)
        XCTAssertEqual(a.flatten, 1, accuracy: 1e-9)
        XCTAssertEqual(a.displayPiece?.isFaceUp, false, "移动途中仍是背面")

        // 移动段中点：滑到一半（缓入缓出，正中恰好 0.5）
        a.progress = 0.3
        XCTAssertEqual(a.easedMove, 0.5, accuracy: 1e-9)
        XCTAssertEqual(a.flatten, 1, accuracy: 1e-9)

        // 移动段结束：正好落在终点，还没翻面
        a.progress = 0.6
        XCTAssertEqual(a.easedMove, 1, accuracy: 1e-9)
        XCTAssertEqual(a.flipProgress ?? -1, 0, accuracy: 1e-9)

        // 翻面过半：压到最扁，且已经换成翻开后的那一面
        a.progress = 0.8
        XCTAssertEqual(a.flipProgress ?? -1, 0.5, accuracy: 1e-9)
        XCTAssertEqual(a.flatten, 0.06, accuracy: 1e-6, "翻面到一半时棋子几乎没有宽度")
        XCTAssertEqual(a.displayPiece?.isFaceUp, true, "翻过一半就换成明牌的面")

        // 播完：展开回原样，明牌
        a.progress = 1.0
        XCTAssertEqual(a.flatten, 1, accuracy: 1e-9)
        XCTAssertEqual(a.displayPiece?.isFaceUp, true)
    }

    func testFaceUpPieceTimeline() {
        var a = MoveAnimation(from: Point(9, 0), to: Point(7, 0),
                              mover: piece(faceUp: true), victim: nil, didReveal: false)
        XCTAssertEqual(a.duration, 0.6, accuracy: 1e-9, "明子没有可翻的面，只有移动段")

        XCTAssertNil(a.flipProgress, "明子不该有翻面段")
        a.progress = 0.5
        XCTAssertEqual(a.flatten, 1, accuracy: 1e-9, "明子不该被压扁")

        a.progress = 1.0
        XCTAssertEqual(a.easedMove, 1, accuracy: 1e-9)
        XCTAssertEqual(a.displayPiece?.isFaceUp, true)
    }

    /// 被吃掉的棋子不参与翻面：这一步只是「谁被吃掉了」，淡出由 UI 按 easedMove 算
    func testCaptureKeepsVictimAside() {
        let victim = Piece(.black, .soldier, isFaceUp: true)
        var a = MoveAnimation(from: Point(9, 0), to: Point(8, 0),
                              mover: piece(faceUp: true), victim: victim, didReveal: false)
        a.progress = 1.0
        XCTAssertEqual(a.victim, victim, "被吃的棋子原样留在动画里，供 UI 淡出")
        XCTAssertEqual(a.displayPiece, a.mover, "走过去的是走子的那枚，不是被吃的")
    }
}
