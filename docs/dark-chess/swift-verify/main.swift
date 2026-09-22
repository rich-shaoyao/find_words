//
//  main.swift — 引擎命令行自检
//
//  用法（在仓库根目录执行）：
//    swiftc -O -D STANDALONE_CHECK \
//           flip_chess/Engine/*.swift flip_chessTests/EngineChecks.swift \
//           docs/dark-chess/swift-verify/main.swift -o /tmp/xq-selfcheck && /tmp/xq-selfcheck
//
//  -D STANDALONE_CHECK 是为了让 EngineChecks.swift 跳过 @testable import
//  （同批编译时它和 Engine 是同一个模块，写了反而报 "no such module"）。
//
//  它直接跑 flip_chessTests/EngineChecks.swift 里的断言表，**不依赖 Xcode 工程**。
//  这样即使整包构建暂时跑不起来，
//  引擎的正确性依然随时可验证。
//

import Foundation

let (passed, failures) = EngineChecks.runAll(verbose: true)

print("\n──────────────────────────────")
if failures.isEmpty {
    print("✅ 全部通过：\(passed) 项断言")
} else {
    print("❌ \(failures.count) 项失败 / 共 \(passed + failures.count) 项")
    for f in failures { print(" - \(f)") }
}
exit(failures.isEmpty ? 0 : 1)
