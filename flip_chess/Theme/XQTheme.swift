//
//  XQTheme.swift
//  Flip Chess: Dark Xiangqi — 主题令牌
//
//  色彩与几何数值与 Web 原型 docs/dark-chess/prototype.html 的 CSS 令牌一一对应，
//  这样 iOS 版与原型看起来是同一个东西（原型是视觉基准）。
//

import SwiftUI

extension Color {
    /// 0xRRGGBB → Color
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

public enum XQTheme {

    // MARK: 色彩

    public static let gold = Color(hex: 0xD8B65E)
    public static let goldDeep = Color(hex: 0x9A7B34)
    public static let goldLight = Color(hex: 0xF3E3B4)
    public static let red = Color(hex: 0xC0392B)
    /// 红方棋子的墨色（比 --red 略沉，落在米白盘面上更清楚）
    public static let redInk = Color(hex: 0xB0241C)
    public static let blackInk = Color(hex: 0x1A1A1A)

    public static let text = Color(hex: 0xEDE6D6)
    public static let textDim = Color(hex: 0xA99F8A)
    public static let textFaint = Color(hex: 0x5E5748)

    public static let panel = Color.white.opacity(0.055)
    public static let panelBorder = Color.white.opacity(0.10)

    public static let bannerWarn = Color(hex: 0xE7B45E)
    public static let bannerGood = Color(hex: 0x8FD6A0)
    public static let hintCyan = Color(hex: 0x6FD1E8)

    // MARK: 背景

    /// 主菜单 / 对局页的底色（深蓝夜色）
    public static let background = LinearGradient(
        stops: [
            .init(color: Color(hex: 0x1C2B49), location: 0.00),
            .init(color: Color(hex: 0x0C1322), location: 0.46),
            .init(color: Color(hex: 0x04060C), location: 1.00),
        ],
        startPoint: .top, endPoint: .bottom)

    /// 棋盘木面
    public static let boardSurface = LinearGradient(
        stops: [
            .init(color: Color(hex: 0xEDD3A6), location: 0.00),
            .init(color: Color(hex: 0xDFBC88), location: 0.46),
            .init(color: Color(hex: 0xCFA46D), location: 1.00),
        ],
        startPoint: .topLeading, endPoint: .bottomTrailing)

    /// 棋子正面的象牙白（对应 CSS 的 radial-gradient #ivory）
    public static let ivory = RadialGradient(
        colors: [Color(hex: 0xFFFCF1), Color(hex: 0xF2E6C9), Color(hex: 0xDCC49A)],
        center: UnitPoint(x: 0.34, y: 0.26), startRadius: 0, endRadius: 44)

    /// 暗棋背面的深木色（对应 CSS 的 #darkwood）
    public static let darkWood = RadialGradient(
        colors: [Color(hex: 0x54402C), Color(hex: 0x3A2417), Color(hex: 0x1E1109)],
        center: UnitPoint(x: 0.34, y: 0.24), startRadius: 0, endRadius: 46)

    /// 棋盘线
    public static let lineColor = Color(hex: 0x7B5230)
    public static let lineColorDeep = Color(hex: 0x6A4425)
    public static let riverText = Color(hex: 0x7B5230)

    // MARK: 棋盘几何（与 prototype.html 的 PAD / CELL / VBW / VBH 一致）

    public static let boardRows = 10
    public static let boardCols = 9
    public static let pad: CGFloat = 60      // 棋盘外缘留白
    public static let cell: CGFloat = 100    // 交叉点间距
    public static let boardWidth: CGFloat = pad * 2 + cell * 8    // 920
    public static let boardHeight: CGFloat = pad * 2 + cell * 9   // 1020

    /// 棋子半径
    public static let pieceRadius: CGFloat = 44
    public static let pieceRingRadius: CGFloat = 36

    /// 交叉点 → 画布坐标
    public static func x(_ col: Int) -> CGFloat { pad + CGFloat(col) * cell }
    public static func y(_ row: Int) -> CGFloat { pad + CGFloat(row) * cell }

    // MARK: 汉字字体（棋子面与标题）
    //
    // 原型用 "Kaiti SC"；iOS 上中文书法体是 "STKaiti" / "Kaiti SC"，
    // 拿不到时退回系统衬线体，视觉上仍然端庄。
    public static func calligraphy(_ size: CGFloat) -> Font {
        if UIFont(name: "STKaiti", size: size) != nil { return .custom("STKaiti", size: size) }
        if UIFont(name: "Kaiti SC", size: size) != nil { return .custom("Kaiti SC", size: size) }
        return .system(size: size, weight: .bold, design: .serif)
    }

    /// 标题用的拉丁衬线体（英文 App 名）
    public static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }
}
