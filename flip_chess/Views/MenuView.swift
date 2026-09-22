//
//  MenuView.swift
//  Flip Chess: Dark Xiangqi — 主菜单
//

import SwiftUI

struct MenuView: View {

    @Binding var level: AILevel
    @State private var soundOn = true
    let onStart: (GameMode, AILevel) -> Void
    let onHelp: () -> Void

    var body: some View {
        VStack(spacing: 34) {
            Spacer()

            VStack(spacing: 14) {
                // App 名（英文版）。汉字书法体是给盘面用的，拉丁字形交给衬线体。
                Text("Flip Chess")
                    .font(.system(size: 54, weight: .semibold, design: .serif))
                    .foregroundStyle(
                        LinearGradient(colors: [Color(hex: 0xFBF0CF), XQTheme.gold, Color(hex: 0x8A6E33)],
                                       startPoint: .top, endPoint: .bottom))
                    .shadow(color: XQTheme.gold.opacity(0.28), radius: 26)
                Text("DARK XIANGQI · ONE MOVE TO FLIP IT")
                    .font(.system(size: 12.5, weight: .medium))
                    .tracking(2.2)
                    .foregroundStyle(XQTheme.textDim)
            }

            VStack(spacing: 12) {
                // 难度
                HStack(spacing: 4) {
                    ForEach(AILevel.allCases, id: \.rawValue) { lv in
                        Button {
                            level = lv
                        } label: {
                            Text(label(for: lv))
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(level == lv
                                              ? LinearGradient(colors: [XQTheme.gold, Color(hex: 0xA9853C)],
                                                               startPoint: .top, endPoint: .bottom)
                                              : LinearGradient(colors: [.clear, .clear],
                                                               startPoint: .top, endPoint: .bottom))
                                )
                                .foregroundStyle(level == lv ? Color(hex: 0x20160A) : XQTheme.textDim)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 13).fill(Color.black.opacity(0.28)))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(XQTheme.panelBorder, lineWidth: 1))
                .frame(width: 252)

                MenuButton(title: "Play vs Computer", primary: true) { onStart(.vsAI, level) }
                MenuButton(title: "Two Players") { onStart(.twoPlayers, level) }
                MenuButton(title: "How to Play") { onHelp() }

                Toggle(isOn: $soundOn) {
                    Text("Sound").font(.system(size: 14)).foregroundStyle(XQTheme.textDim)
                }
                .toggleStyle(.switch)
                .tint(Color(hex: 0xC49B44))
                .frame(width: 252)
                .onChange(of: soundOn) { _, on in SoundKit.shared.enabled = on }
            }

            Spacer()

            Text("Interactive prototype · rules & game feel")
                .font(.system(size: 11.5))
                .tracking(1.4)
                .foregroundStyle(XQTheme.textFaint)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(XQTheme.background)
    }

    private func label(for lv: AILevel) -> String {
        switch lv {
        case .easy: return "Easy"
        case .normal: return "Normal"
        case .hard: return "Hard"
        }
    }
}

struct MenuButton: View {
    let title: String
    var primary: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .tracking(1.2)
                .frame(width: 252)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(primary
                              ? LinearGradient(colors: [Color(hex: 0xEBD08A), Color(hex: 0xC49B44), Color(hex: 0xA07C33)],
                                               startPoint: .top, endPoint: .bottom)
                              : LinearGradient(colors: [Color.white.opacity(0.085), Color.white.opacity(0.028)],
                                               startPoint: .top, endPoint: .bottom))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(primary ? Color(hex: 0xEFD9A0) : XQTheme.panelBorder, lineWidth: 1)
                )
                .foregroundStyle(primary ? Color(hex: 0x20160A) : XQTheme.text)
        }
        .buttonStyle(.plain)
    }
}
