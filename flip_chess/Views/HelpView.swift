//
//  HelpView.swift
//  Flip Chess: Dark Xiangqi — 玩法说明（英文）
//
//  对应 ui.js 的 showHelp：8 条规则，逐条对齐。
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let items: [(String, String)] = [
        ("Setup", "All 32 standard Xiangqi points are filled. Both Generals start face-up on their own back-rank centre; the remaining 30 pieces are face-down and shuffled together — Red and Black mixed. You never know who stands where, or whose piece it is. Long-press any piece for about half a second to see its English name and how it moves."),
        ("Turn", "Each turn you step one of your pieces. There is no “flip in place” — the only way to reveal a hidden piece is to move it."),
        ("Reveal by pushing", "A hidden piece flips face-up the moment it finishes its move. So “pushing a hidden piece” is the core action: it may turn out to be your Chariot, or your opponent’s — you only find out by moving it."),
        ("Hidden pieces move", "A face-down piece moves according to the standard piece of the point it occupies — on a back-rank Chariot point it slides like a Chariot, on a Soldier point it steps one square forward. It flips after moving, and from then on follows its real identity."),
        ("Capturing", "Only two things can be captured: the opponent’s face-up pieces, and hidden pieces sitting in the opponent’s half (no matter who they really belong to). Hidden pieces in your own half can never be captured — push them out to deal with them. Sides are judged only from open information."),
        ("Movement", "Once face-up, standard Xiangqi rules apply: the Chariot slides, the Horse moves in an L (its leg can be blocked), the Cannon captures over exactly one screen. Screens may be face-down, and a Cannon can capture the General — but a face-down Cannon can only sit on a Cannon point, which cannot reach the enemy back-rank centre, so a one-move kill has to wait until a Cannon is revealed."),
        ("House rules", "Advisor and Elephant are not restricted to their own side — they may cross the river and enter the palace. The General may only move inside its own 3×3 palace. Soldiers never move backward and may step sideways once across the river."),
        ("Winning", "Capture the enemy General to win. A side with no legal move loses. 60 moves each with no capture and no flip is a draw."),
    ]

    var body: some View {
        ZStack {
            XQTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How to Play")
                        .font(XQTheme.calligraphy(30))
                        .foregroundStyle(XQTheme.gold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 8)

                    ForEach(items, id: \.0) { title, body in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(XQTheme.gold)
                            Text(body)
                                .font(.system(size: 13.5))
                                .lineSpacing(5)
                                .foregroundStyle(Color(hex: 0xB7AE99))
                        }
                    }

                    MenuButton(title: "Got it", primary: true) { dismiss() }
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(24)
            }
        }
        .presentationDetents([.large])
    }
}
