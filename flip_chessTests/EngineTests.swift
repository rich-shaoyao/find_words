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
