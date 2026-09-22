//
//  GameView.swift
//  Flip Chess: Dark Xiangqi — 对局页（HUD + 提示条 + 棋盘 + 工具栏）
//

import SwiftUI

struct GameView: View {

    @ObservedObject var store: GameStore
    let onBack: () -> Void
    @State private var showHelp = false

    var body: some View {
        VStack(spacing: 0) {
            hud(for: .black)
                .padding(.horizontal, 12)

            banner
                .padding(.horizontal, 16)

            BoardView(store: store)
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)

            hud(for: .red)
                .padding(.horizontal, 12)

            tools
        }
        .background(XQTheme.background)
        .sheet(isPresented: $showHelp) { HelpView() }
        .sheet(item: $store.result) { info in
            ResultSheet(info: info,
                        onPlayAgain: { store.start(mode: store.mode, level: store.level) },
                        onBack: onBack)
        }
    }

    // MARK: HUD

    private func hud(for side: Side) -> some View {
        let isTurn = !store.state.isOver && store.state.turn == side
        let isTop = side == .black
        return HStack(spacing: 10) {
            Circle()
                .fill(side == .red
                      ? RadialGradient(colors: [Color(hex: 0xE86A55), Color(hex: 0xA62B1E)],
                                       center: UnitPoint(x: 0.34, y: 0.28), startRadius: 2, endRadius: 22)
                      : RadialGradient(colors: [Color(hex: 0x5D5A54), Color(hex: 0x1B1916)],
                                       center: UnitPoint(x: 0.34, y: 0.28), startRadius: 2, endRadius: 22))
                .frame(width: 34, height: 34)
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(isTop ? store.opponentName() : store.myName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(XQTheme.text)
                Text("Hidden \(store.hiddenCount(for: side))")
                    .font(.system(size: 11))
                    .foregroundStyle(XQTheme.textDim)
            }
            .frame(minWidth: 74, alignment: .leading)

            Spacer(minLength: 4)

            // 战利品
            HStack(spacing: 2) {
                ForEach(Array(store.capturedList(for: side).enumerated()), id: \.offset) { _, cap in
                    ZStack {
                        Circle().fill(LinearGradient(colors: [Color(hex: 0xFBF3DF), Color(hex: 0xDFCDA6)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 19, height: 19)
                        Text(Board.name[cap.type]?[side] ?? "?")
                            .font(XQTheme.calligraphy(11))
                            .foregroundStyle(side == .red ? XQTheme.redInk : XQTheme.blackInk)
                    }
                    .opacity(cap.wasFaceUp ? 0.82 : 0.5)
                }
            }
            .frame(maxWidth: 150, alignment: .trailing)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(XQTheme.panel)
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .stroke(isTurn ? XQTheme.gold.opacity(0.55) : XQTheme.panelBorder, lineWidth: 1))
        )
        .shadow(color: isTurn ? XQTheme.gold.opacity(0.35) : .clear, radius: 12, y: 6)
        .padding(.vertical, 4)
    }

    // MARK: 提示条

    private var banner: some View {
        Text(store.banner)
            .font(.system(size: 12.5))
            .foregroundStyle(toneColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding(.vertical, 7)
    }

    private var toneColor: Color {
        switch store.bannerTone {
        case .normal: return Color(hex: 0xC6BCA4)
        case .warn:   return XQTheme.bannerWarn
        case .good:   return XQTheme.bannerGood
        }
    }

    // MARK: 工具栏

    private var tools: some View {
        HStack(spacing: 8) {
            ToolButton(title: "Undo", disabled: !store.canUndo) { store.undo() }
            ToolButton(title: "Hint") { store.showHint() }
            ToolButton(title: "Resign") { store.resign() }
            ToolButton(title: "Help") { showHelp = true }
            ToolButton(title: "Menu") { onBack() }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
}

struct ToolButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13.5, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                                             startPoint: .top, endPoint: .bottom))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(XQTheme.panelBorder, lineWidth: 1))
                )
                .foregroundStyle(Color(hex: 0xD9D0BC))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.34 : 1)
    }
}
