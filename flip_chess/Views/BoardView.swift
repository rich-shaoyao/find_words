//
//  BoardView.swift
//  Flip Chess: Dark Xiangqi — 棋盘与棋子渲染
//
//  用 SwiftUI Canvas 一次性画整盘（棋盘线 + 32 枚棋子 + 高亮），
//  比 32 个 View 轻得多，翻面动效也能直接操作 GraphicsContext。
//
//  交互用 DragGesture(minimumDistance: 0) 而不是 TapGesture：
//  同一个手势既能识别「短点走棋」，也能识别「长按 0.52s 看英文说明」，
//  并且能拿到按下坐标做棋盘坐标换算。
//

import SwiftUI

struct BoardView: View {

    @ObservedObject var store: GameStore

    /// 长按阈值。与 Web 原型的 PRESS_MS 一致。
    private let pressSeconds = 0.52
    /// 手指微动宽容度（超过就取消长按）
    private let moveTolerance: CGFloat = 12

    @State private var pressStartDate: Date?
    @State private var pressPoint: Point?
    @State private var pressFired = false
    @State private var longPressTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let scale = min(geo.size.width / XQTheme.boardWidth,
                            geo.size.height / XQTheme.boardHeight)
            let offX = (geo.size.width - XQTheme.boardWidth * scale) / 2
            let offY = (geo.size.height - XQTheme.boardHeight * scale) / 2

            Canvas { ctx, _ in
                ctx.translateBy(x: offX, y: offY)
                ctx.scaleBy(x: scale, y: scale)
                drawBoard(ctx)
                drawPieces(ctx)
            }
            .background(
                RoundedRectangle(cornerRadius: 17)
                    .fill(XQTheme.boardSurface)
            )
            .clipShape(RoundedRectangle(cornerRadius: 17))
            .shadow(color: .black.opacity(0.6), radius: 22, y: 14)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let cell = cellAt(value.location, scale: scale, offX: offX, offY: offY)
                        if pressStartDate == nil {
                            pressStartDate = Date()
                            pressPoint = cell
                            pressFired = false
                            if let cell { scheduleLongPress(cell) }
                        } else if let start = pressPoint {
                            // 位移超过宽容度 → 取消长按（但也不当作点击）
                            let startPt = pointOf(start, scale: scale, offX: offX, offY: offY)
                            let dx = abs(value.location.x - startPt.x)
                            let dy = abs(value.location.y - startPt.y)
                            if dx + dy > moveTolerance { cancelLongPress() }
                        }
                    }
                    .onEnded { value in
                        defer { resetPress() }
                        if pressFired { return }   // 长按已消费这次交互，别再走棋
                        let cell = cellAt(value.location, scale: scale, offX: offX, offY: offY)
                        if let cell { store.tap(cell) }
                    }
            )
        }
        .aspectRatio(XQTheme.boardWidth / XQTheme.boardHeight, contentMode: .fit)
    }

    // MARK: 长按

    private func scheduleLongPress(_ cell: Point) {
        longPressTask?.cancel()
        longPressTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(pressSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                pressFired = true
                store.longPress(cell)
            }
        }
    }

    private func cancelLongPress() {
        longPressTask?.cancel()
        longPressTask = nil
    }

    private func resetPress() {
        cancelLongPress()
        pressStartDate = nil
        pressPoint = nil
    }

    // MARK: 坐标换算

    private func cellAt(_ loc: CGPoint, scale: CGFloat, offX: CGFloat, offY: CGFloat) -> Point? {
        let x = (loc.x - offX) / scale
        let y = (loc.y - offY) / scale
        let c = Int(((x - XQTheme.pad) / XQTheme.cell).rounded())
        let r = Int(((y - XQTheme.pad) / XQTheme.cell).rounded())
        guard r >= 0, r < XQTheme.boardRows, c >= 0, c < XQTheme.boardCols else { return nil }
        // 落点必须离交叉点够近，避免点到格子中间
        let dx = x - XQTheme.x(c), dy = y - XQTheme.y(r)
        guard dx * dx + dy * dy <= 54 * 54 else { return nil }
        return Point(r, c)
    }

    private func pointOf(_ p: Point, scale: CGFloat, offX: CGFloat, offY: CGFloat) -> CGPoint {
        CGPoint(x: offX + XQTheme.x(p.c) * scale, y: offY + XQTheme.y(p.r) * scale)
    }

    // MARK: 绘制

    private func drawBoard(_ ctx: GraphicsContext) {
        let pad = XQTheme.pad, cell = XQTheme.cell

        // 外框
        let frameOut = Path(CGRect(x: pad - 14, y: pad - 14,
                                   width: cell * 8 + 28, height: cell * 9 + 28))
        ctx.stroke(frameOut, with: .color(Color(hex: 0x57381D).opacity(0.65)), lineWidth: 1.6)

        // 横线（10 条，贯通）
        for r in 0...9 {
            var p = Path()
            p.move(to: CGPoint(x: XQTheme.x(0), y: XQTheme.y(r)))
            p.addLine(to: CGPoint(x: XQTheme.x(8), y: XQTheme.y(r)))
            ctx.stroke(p, with: .color(XQTheme.lineColor), lineWidth: 1.6)
        }
        // 竖线（9 条，中间 7 条被河界断开）
        for c in 0...8 {
            if c == 0 || c == 8 {
                var p = Path()
                p.move(to: CGPoint(x: XQTheme.x(c), y: XQTheme.y(0)))
                p.addLine(to: CGPoint(x: XQTheme.x(c), y: XQTheme.y(9)))
                ctx.stroke(p, with: .color(XQTheme.lineColor), lineWidth: 1.6)
            } else {
                for (a, b) in [(0, 4), (5, 9)] {
                    var p = Path()
                    p.move(to: CGPoint(x: XQTheme.x(c), y: XQTheme.y(a)))
                    p.addLine(to: CGPoint(x: XQTheme.x(c), y: XQTheme.y(b)))
                    ctx.stroke(p, with: .color(XQTheme.lineColor), lineWidth: 1.6)
                }
            }
        }
        // 九宫斜线
        let palaces: [(CGPoint, CGPoint, CGPoint, CGPoint)] = [
            (CGPoint(x: XQTheme.x(3), y: XQTheme.y(0)), CGPoint(x: XQTheme.x(5), y: XQTheme.y(2)),
             CGPoint(x: XQTheme.x(5), y: XQTheme.y(0)), CGPoint(x: XQTheme.x(3), y: XQTheme.y(2))),
            (CGPoint(x: XQTheme.x(3), y: XQTheme.y(7)), CGPoint(x: XQTheme.x(5), y: XQTheme.y(9)),
             CGPoint(x: XQTheme.x(5), y: XQTheme.y(7)), CGPoint(x: XQTheme.x(3), y: XQTheme.y(9))),
        ]
        for (a, b, c, d) in palaces {
            var p1 = Path(); p1.move(to: a); p1.addLine(to: b)
            var p2 = Path(); p2.move(to: c); p2.addLine(to: d)
            ctx.stroke(p1, with: .color(XQTheme.lineColor.opacity(0.85)), lineWidth: 1.4)
            ctx.stroke(p2, with: .color(XQTheme.lineColor.opacity(0.85)), lineWidth: 1.4)
        }
        // 内框
        let frame = Path(CGRect(x: XQTheme.x(0), y: XQTheme.y(0),
                                width: cell * 8, height: cell * 9))
        ctx.stroke(frame, with: .color(XQTheme.lineColorDeep), lineWidth: 3.4)

        // 「楚河 / 汉界」——海外版改成英文，字号比汉字小（拉丁字母横向更长）
        ctx.draw(
            Text("CHU RIVER")
                .font(.system(size: 38, weight: .regular, design: .serif))
                .foregroundStyle(XQTheme.riverText.opacity(0.62)),
            at: CGPoint(x: XQTheme.x(2), y: XQTheme.y(4) + cell / 2), anchor: .center)
        ctx.draw(
            Text("HAN BORDER")
                .font(.system(size: 38, weight: .regular, design: .serif))
                .foregroundStyle(XQTheme.riverText.opacity(0.62)),
            at: CGPoint(x: XQTheme.x(6), y: XQTheme.y(4) + cell / 2), anchor: .center)
    }

    private func drawPieces(_ ctx: GraphicsContext) {
        let state = store.state

        // 最近一步
        if let last = state.last {
            for (p, isTarget) in [(last.from, false), (last.to, true)] {
                let rect = CGRect(x: XQTheme.x(p.c) - 46, y: XQTheme.y(p.r) - 46, width: 92, height: 92)
                let path = Path(ellipseIn: rect)
                ctx.stroke(path,
                           with: .color(isTarget ? XQTheme.redInk.opacity(0.55)
                                                 : XQTheme.goldDeep.opacity(0.62)),
                           style: StrokeStyle(lineWidth: 2.6, dash: isTarget ? [] : [7, 7]))
            }
        }

        // 落点标记
        for t in store.legalTargets {
            let centre = CGPoint(x: XQTheme.x(t.c), y: XQTheme.y(t.r))
            let isCapture = state.piece(at: t) != nil
            if isCapture {
                let rect = CGRect(x: centre.x - 45, y: centre.y - 45, width: 90, height: 90)
                ctx.stroke(Path(ellipseIn: rect),
                           with: .color(XQTheme.gold.opacity(0.95)),
                           style: StrokeStyle(lineWidth: 4, dash: [11, 9]))
            } else {
                let rect = CGRect(x: centre.x - 15, y: centre.y - 15, width: 30, height: 30)
                ctx.fill(Path(ellipseIn: rect), with: .color(XQTheme.gold.opacity(0.62)))
            }
        }

        // 提示
        if let hint = store.hint {
            for p in [hint.from, hint.to] {
                let rect = CGRect(x: XQTheme.x(p.c) - 47, y: XQTheme.y(p.r) - 47, width: 94, height: 94)
                ctx.stroke(Path(ellipseIn: rect), with: .color(XQTheme.hintCyan), lineWidth: 3.4)
            }
        }

        // 刚翻开的棋子：外圈金色扩散环（翻面动效）
        if let rev = store.revealAnimation {
            let centre = CGPoint(x: XQTheme.x(rev.c), y: XQTheme.y(rev.r))
            for step in 0..<3 {
                let rr = 46 + CGFloat(step) * 12
                let rect = CGRect(x: centre.x - rr, y: centre.y - rr, width: rr * 2, height: rr * 2)
                ctx.stroke(Path(ellipseIn: rect),
                           with: .color(XQTheme.gold.opacity(0.55 - Double(step) * 0.17)),
                           lineWidth: 3)
            }
        }

        // 棋子
        for r in 0..<XQTheme.boardRows {
            for c in 0..<XQTheme.boardCols {
                guard let p = state.piece(at: r, c) else { continue }
                drawPiece(ctx, piece: p, at: Point(r, c))
            }
        }
    }

    private func drawPiece(_ ctx: GraphicsContext, piece: Piece, at p: Point) {
        let cx = XQTheme.x(p.c), cy = XQTheme.y(p.r)
        let r = XQTheme.pieceRadius
        let isSelected = store.selected == p

        // 阴影
        ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r + 6, width: r * 2, height: r * 2)),
                 with: .color(Color(hex: 0x3A2208).opacity(0.30)))

        let isRed = piece.side == .red
        let ink = isRed ? XQTheme.redInk : XQTheme.blackInk

        if piece.isFaceUp {
            // 明棋：象牙白 + 归属色描边
            if piece.type == .king {
                ctx.stroke(Path(ellipseIn: CGRect(x: cx - 50, y: cy - 50, width: 100, height: 100)),
                           with: .color(XQTheme.gold.opacity(0.16)), lineWidth: 7)
            }
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                     with: .style(XQTheme.ivory))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                       with: .color(isRed ? Color(hex: 0x9E2B25) : Color(hex: 0x241F1A)), lineWidth: 2.6)
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - 36, y: cy - 36, width: 72, height: 72)),
                       with: .color(ink.opacity(0.7)), lineWidth: 1.5)
            if piece.type == .king {
                ctx.stroke(Path(ellipseIn: CGRect(x: cx - 47, y: cy - 47, width: 94, height: 94)),
                           with: .color(XQTheme.gold.opacity(0.95)), lineWidth: 2.4)
            }
            // 棋子面**只画汉字并居中**：大小完全由传统比例决定，不被文字撑大。
            // 英文名不常驻盘面（那会把棋子挤大），改为**长按**时弹出说明。
            ctx.draw(
                Text(Board.displayName(piece))
                    .font(XQTheme.calligraphy(54))
                    .foregroundStyle(ink),
                at: CGPoint(x: cx, y: cy), anchor: .center)
        } else {
            // 暗棋：深木色 + 虚线金环 + ?
            ctx.fill(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                     with: .style(XQTheme.darkWood))
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                       with: .color(Color(hex: 0x8A6E33)), lineWidth: 2.2)
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - 36, y: cy - 36, width: 72, height: 72)),
                       with: .color(Color(hex: 0xC9A227).opacity(0.72)),
                       style: StrokeStyle(lineWidth: 1.3, dash: [9, 7]))
            ctx.draw(
                Text("?").font(XQTheme.calligraphy(44))
                    .foregroundStyle(Color(hex: 0xC9A227).opacity(0.9)),
                at: CGPoint(x: cx, y: cy), anchor: .center)
        }

        // 选中环
        if isSelected {
            ctx.stroke(Path(ellipseIn: CGRect(x: cx - 51, y: cy - 51, width: 102, height: 102)),
                       with: .color(XQTheme.gold),
                       style: StrokeStyle(lineWidth: 2.6, dash: [13, 11]))
        }
    }
}
