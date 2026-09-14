//
//  find_wordsApp.swift
//  find_words
//
//  Created by 李少尧 on 2026/9/12.
//

import SwiftUI

@main
struct find_wordsApp: App {

    init() {
        // Start the Google Mobile Ads SDK once, before the first ad request.
        // Info.plist carries the matching GADApplicationIdentifier (Debug-only; see Info.plist).
        // 无广告构建（Release 或 SWIFT_ACTIVE_COMPILATION_CONDITIONS 未含 HIDDEN_AD_PANEL_ENABLED）
        // 整段不编译，App 不加载任何广告 SDK。
        #if HIDDEN_AD_PANEL_ENABLED
        CluvioAds.shared.startSDK()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
