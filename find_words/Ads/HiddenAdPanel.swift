//
//  HiddenAdPanel.swift
//  find_words
//
//  隐藏广告面板（见 ad_layout skill 第 8 节）—— 渠道/测试验证用途，不是产品功能。
//
//  形态（skill 8.2「横屏全宽表格」）：
//    · 白色圆角容器：横向铺满窗口宽（左右仅 10pt 边距）、纵向铺满窗口高（上下仅 12pt 留白）
//    · 行高按窗口高度自适应均分，上限 96pt（防竖屏过高），整块内容垂直居中，右上角 ✕ 关闭
//    · 顶部标题区黑字两列：Rewarded Video / Interstitial，各自对齐到下方窗口列
//    · 每广告平台一行（六行：AdMob / Meta / Vungle / Chartboost / InMobi / Unity Ads），无平台名列；
//      每行两个窗口横向平均分布并排占满整行
//    · 左窗 = 该平台激励视频（浅蓝 163,214,252），右窗 = 该平台插屏（浅橙 255,217,171）
//    · 可点击态：实心蓝 (0,152,251) + 白字；未接入 / 暂无广告 / 加载中 / 播放中 / 倒计时：浅底 + 白字（不可点）
//    · 窗口标题为中文「类型 + 状态」两行；面板弹出后不额外弹 Toast/弹窗，反馈收敛在窗口文案里
//
//  整个面板与触发实现由宏 HIDDEN_AD_PANEL_ENABLED 控制是否编译
//  （Debug 配置默认开启用于渠道验证；App Store 上架打包时去掉该宏即可，见 pbxproj 的
//   SWIFT_ACTIVE_COMPILATION_CONDITIONS）。
//

import SwiftUI

#if HIDDEN_AD_PANEL_ENABLED

// MARK: - 平台行

/// 面板里的平台行。与「已接入平台」解耦：六行全部展示，未接入的窗口显示「未接入」灰态（skill 8.3）。
enum QiPlatform: Int, CaseIterable, Identifiable {
    case admob
    case meta
    case vungle
    case chartboost
    case inmobi
    case unityAds

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .admob:      return "AdMob"
        case .meta:       return "Meta"
        case .vungle:     return "Vungle"
        case .chartboost: return "Chartboost"
        case .inmobi:     return "InMobi"
        case .unityAds:   return "Unity Ads"
        }
    }

    /// 当前只有 AdMob 走 QiAdManager 真接入。
    var isConnected: Bool { self == .admob }
}

// MARK: - 面板开关

/// `QiHiddenAdPanel show` 的 SwiftUI 等价物：一个全局开关 + 打开时预载广告。
final class QiHiddenAdPanel: ObservableObject {

    static let shared = QiHiddenAdPanel()

    @Published var isPresented = false

    private init() {}

    func show() {
        guard !isPresented else { return }
        NSLog("[QiHiddenAdPanel] show")
        isPresented = true
        QiAdManager.shared.preloadAds()
    }

    func hide() {
        guard isPresented else { return }
        NSLog("[QiHiddenAdPanel] hide")
        isPresented = false
    }
}

// MARK: - 展示宿主（挂在 RootView 的 overlay 上）

/// 面板打开时覆盖所有界面；关闭时不占位。
struct HiddenAdPanelOverlay: View {

    @ObservedObject private var panel = QiHiddenAdPanel.shared

    var body: some View {
        if panel.isPresented {
            HiddenAdPanelView()
                .transition(.opacity)
        }
    }
}

// MARK: - 面板

struct HiddenAdPanelView: View {

    @ObservedObject private var panel = QiHiddenAdPanel.shared
    @ObservedObject private var ads = QiAdManager.shared

    private let outerMargin: CGFloat = 10
    private let verticalInset: CGFloat = 12
    private let rowSpacing: CGFloat = 8
    private let maxRowHeight: CGFloat = 96

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(0, proxy.size.width - outerMargin * 2)
            let panelHeight = max(0, proxy.size.height - verticalInset * 2)
            let header: CGFloat = 26
            let rows = CGFloat(QiPlatform.allCases.count)
            let rowHeight = min(maxRowHeight, max(40, (panelHeight - header - rowSpacing * rows) / rows))

            VStack(spacing: rowSpacing) {
                headerRow
                ForEach(QiPlatform.allCases) { platform in
                    platformRow(platform, height: rowHeight)
                }
            }
            .frame(width: contentWidth, height: panelHeight)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Color.white,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    panel.hide()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.black.opacity(0.65))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }

    // MARK: - 标题区（黑字两列，各自对齐下方窗口）

    private var headerRow: some View {
        HStack(spacing: 8) {
            columnTitle("Rewarded Video")
            columnTitle("Interstitial")
        }
        .padding(.horizontal, 2)
        .padding(.trailing, 34) // 给右上角 ✕ 让位
    }

    private func columnTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.black)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 一行：两个窗口横向平均分布

    private func platformRow(_ platform: QiPlatform, height: CGFloat) -> some View {
        HStack(spacing: 8) {
            window(platform: platform, type: .rewarded, height: height)
            window(platform: platform, type: .interstitial, height: height)
        }
    }

    private func window(platform: QiPlatform, type: QiAdType, height: CGFloat) -> some View {
        let status = status(for: platform, type: type)
        let enabled = platform.isConnected && status == .ready

        return Button {
            guard enabled else { return }
            QiAdManager.shared.showAd(of: type)
        } label: {
            VStack(spacing: 2) {
                Text(type.displayName)
                    .font(.system(size: 14, weight: .bold))
                Text(platform.isConnected ? statusText(status) : "未接入")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background(for: type, status: status), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .frame(height: height)
    }

    // MARK: - 状态与样式

    private func status(for platform: QiPlatform, type: QiAdType) -> QiAdState {
        guard platform.isConnected else { return .unavailable }
        return ads.state[type] ?? .idle
    }

    private func statusText(_ status: QiAdState) -> String {
        switch status {
        case .idle, .loading:   return "加载中…"
        case .ready:            return "点击播放"
        case .unavailable:      return "暂无广告"
        case .playing:          return "播放中…"
        case .cooldown(let n):  return "\(n) 秒后恢复"
        }
    }

    private func background(for type: QiAdType, status: QiAdState) -> Color {
        // 加载成功 / 可点击态：实心蓝；其余（浅底）沿用窗口自身的浅蓝 / 浅橙。
        if status == .ready { return Color(red: 0, green: 152 / 255, blue: 251 / 255) }
        switch type {
        case .rewarded:     return Color(red: 163 / 255, green: 214 / 255, blue: 252 / 255)
        case .interstitial: return Color(red: 255 / 255, green: 217 / 255, blue: 171 / 255)
        }
    }
}

#endif
