//
//  FlipChessApp.swift
//  Flip Chess: Dark Xiangqi
//
//  原「猜词」玩法已整体移除；6 家广告 SDK 已通过 CocoaPods 重新接入依赖层，
//  广告位代码集中在 Ads/FlipAds.swift（结算页 Play again 播激励视频），
//  详见 docs/dark-chess/proposal.md §9。
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
