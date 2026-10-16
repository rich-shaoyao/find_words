//
//  RootView.swift
//  Flip Chess: Dark Xiangqi — 菜单 / 对局 路由
//

import SwiftUI

struct RootView: View {

    private enum Screen { case menu, game }

    @State private var screen: Screen = .menu
    @State private var level: AILevel = .normal
    @State private var showHelp = false
    @StateObject private var store = GameStore()

    var body: some View {
        ZStack {
            XQTheme.background.ignoresSafeArea()

            switch screen {
            case .menu:
                MenuView(level: $level, onStart: { mode, lv in
                    store.start(mode: mode, level: lv)
                    screen = .game
                }, onHelp: { showHelp = true })
                .sheet(isPresented: $showHelp) { HelpView() }

            case .game:
                GameView(store: store, onBack: { screen = .menu })
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // 启动 Google Mobile Ads SDK（幂等）并预载一条激励视频，
            // 供结算页 Play again 使用（见 Ads/FlipAds.swift）。
            FlipAds.shared.start()
        }
    }
}
