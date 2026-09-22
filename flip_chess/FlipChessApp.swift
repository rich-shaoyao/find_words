//
//  FlipChessApp.swift
//  Flip Chess: Dark Xiangqi
//
//  原「猜词」玩法已整体移除，6 家广告 SDK 的 CocoaPods 依赖也已清除
//  （见 docs/dark-chess/proposal.md §9）。
//

import SwiftUI

@main
struct FindWordsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
