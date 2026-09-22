//
//  ResultSheet.swift
//  Flip Chess: Dark Xiangqi — 结算弹窗
//

import SwiftUI

struct ResultSheet: View {
    let info: GameStore.ResultInfo
    let onPlayAgain: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            XQTheme.background.ignoresSafeArea()
            VStack(spacing: 18) {
                Text(info.title)
                    .font(XQTheme.calligraphy(30))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: 0xFBF0CF), XQTheme.gold, XQTheme.goldDeep],
                                       startPoint: .top, endPoint: .bottom))

                Text(info.body)
                    .font(.system(size: 13.5))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: 0xB7AE99))

                VStack(spacing: 9) {
                    MenuButton(title: "Play again", primary: true) { onPlayAgain() }
                    MenuButton(title: "Back to menu") { onBack() }
                }
                .padding(.top, 6)
            }
            .padding(26)
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.visible)
    }
}
