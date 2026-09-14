//
//  CluvioAds.swift
//  find_words
//
//  广告抽象层（CluvioAds 模式，见 ad_layout skill 第 5~7 节）——平台无关的三件套：
//
//      loadAd(of:)       加载
//      isAdReady(of:)    是否已就绪
//      showAd(of:)       展示（预检失败则不弹）
//
//  上层（隐藏广告面板、以后的产品内激励入口）只依赖这三个方法；换广告平台时
//  只改本文件「平台适配」一段，调用方不动。
//
//  AdMob 适配要点（对齐 skill 第 6 节生命周期）：
//    · 全屏广告是一次性资源：每次展示后（无论播完、中途关闭还是展示失败）立刻为同类型重新 load
//    · 展示前预检 isAdReady，未就绪绝不 present，避免崩溃
//    · 激励视频的奖励回调（userDidEarnReward）先于关闭回调（adDidDismiss）触发
//    · present 的宿主 VC 按 skill 6.2：优先前台活跃场景的 keyWindow，再逐级取最上层 presentedViewController
//
//  测试期一律使用 AdMob 官方测试 ID（必须与 Info.plist 里的测试 App ID 搭配）；
//  正式 ID 到手后只替换下面两个常量即可。
//

import Foundation
import UIKit
import GoogleMobileAds

// MARK: - 类型与状态

/// 广告位类型。面板按此顺序渲染左右两列。
enum AdType: Int, CaseIterable {
    case rewarded = 0
    case interstitial = 1

    /// 面板窗口标题的第一行（中文「类型+状态」两行文案的类型行）。
    var displayName: String {
        switch self {
        case .rewarded: return "激励视频"
        case .interstitial: return "插屏广告"
        }
    }
}

/// 抽象层对外的加载状态；面板据此渲染窗口高亮与状态行。
enum AdState: Equatable {
    case idle           // 还没发起加载
    case loading        // 加载中…
    case ready          // 点击播放
    case unavailable    // 暂无广告
    case playing        // 播放中…
    case cooldown(Int)  // 播完重拉后的恢复倒计时（N 秒后恢复）
}

/// 加载回调，对齐 skill 5.1 的 `AdLoadCompletion(BOOL success)`。
typealias AdLoadCompletion = (Bool) -> Void

// MARK: - 抽象层

final class CluvioAds: NSObject, ObservableObject {

    static let shared = CluvioAds()

    // MARK: - 广告位 ID（正式 ID 到手后仅需替换此处）

    /// AdMob 官方测试激励视频 ID（须配合测试 App ID `ca-app-pub-3940256099942544~1458002511` 使用）。
    static let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    /// AdMob 官方测试插屏 ID。
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"

    // MARK: - 对外状态

    @Published private(set) var state: [AdType: AdState] = [
        .rewarded: .idle,
        .interstitial: .idle,
    ]

    // MARK: - 平台对象（适配边界之内，不外泄）

    private var rewardedAd: GADRewardedAd?
    private var interstitialAd: GADInterstitialAd?

    private var loadsInFlight: Set<AdType> = []
    private var loadCallbacks: [AdType: [AdLoadCompletion]] = [:]
    private var cooldownTask: Task<Void, Never>?

    /// 正在展示的广告类型 —— 关闭/失败回调据此知道该重拉哪一种（skill 7.3 的 currentType）。
    private var currentType: AdType?
    private var isPresenting = false

    private var didStartSDK = false
    private var didEarnReward = false

    private override init() { super.init() }

    // MARK: - SDK 初始化

    /// 启动 Google Mobile Ads SDK。幂等，可重复调用。
    func startSDK() {
        guard !didStartSDK else { return }
        didStartSDK = true
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    // MARK: - 三件套

    func loadAd(of type: AdType, completion: AdLoadCompletion? = nil) {
        if let completion {
            loadCallbacks[type, default: []].append(completion)
        }
        guard !loadsInFlight.contains(type) else { return }

        loadsInFlight.insert(type)
        if !isPresenting {
            setState(type, .loading)
        }

        let request = GADRequest()
        switch type {
        case .rewarded:
            GADRewardedAd.load(withAdUnitID: Self.rewardedAdUnitID, request: request) { [weak self] ad, error in
                self?.finishLoad(type, ad: ad, error: error)
            }
        case .interstitial:
            GADInterstitialAd.load(withAdUnitID: Self.interstitialAdUnitID, request: request) { [weak self] ad, error in
                self?.finishLoad(type, ad: ad, error: error)
            }
        }
    }

    func isAdReady(of type: AdType) -> Bool {
        switch type {
        case .rewarded:     return rewardedAd != nil
        case .interstitial: return interstitialAd != nil
        }
    }

    /// 展示广告。预检失败（未就绪 / 拿不到宿主 VC / 已有广告在播）时不弹，走 completion(false) 并后台重拉。
    func showAd(of type: AdType, completion: ((Bool) -> Void)? = nil) {
        guard !isPresenting else {
            log("busy, skip show for \(type.displayName)")
            completion?(false)
            return
        }
        guard isAdReady(of: type), let host = Self.topViewController() else {
            log("pre-check failed for \(type.displayName), reload in background")
            setState(type, .unavailable)
            completion?(false)
            if !isAdReady(of: type) { loadAd(of: type) }
            return
        }

        currentType = type
        isPresenting = true
        didEarnReward = false
        setState(type, .playing)

        switch type {
        case .rewarded:
            guard let ad = rewardedAd else { return }
            rewardedAd = nil
            ad.fullScreenContentDelegate = self
            // 先注册奖励回调，再 present（skill 7.2：奖励先于关闭回调触发）。
            ad.present(fromRootViewController: host) { [weak self] in
                self?.didEarnReward = true
                self?.log("user did earn reward")
            }
        case .interstitial:
            guard let ad = interstitialAd else { return }
            interstitialAd = nil
            ad.fullScreenContentDelegate = self
            ad.present(fromRootViewController: host)
        }

        completion?(true)
    }

    /// 面板打开时调用：为还没就绪的类型发起一次后台加载。
    func preloadAds() {
        for type in AdType.allCases where !isAdReady(of: type) && !loadsInFlight.contains(type) {
            loadAd(of: type)
        }
    }

    // MARK: - 加载收尾

    private func finishLoad(_ type: AdType, ad: Any?, error: Error?) {
        loadsInFlight.remove(type)

        var success = false
        if let error {
            log("\(type.displayName) load failed: \(error.localizedDescription)")
        } else {
            switch type {
            case .rewarded:
                if let rewarded = ad as? GADRewardedAd {
                    rewardedAd = rewarded
                    success = true
                }
            case .interstitial:
                if let interstitial = ad as? GADInterstitialAd {
                    interstitialAd = interstitial
                    success = true
                }
            }
        }

        if success {
            // 倒计时期间不打断面板的「N 秒后恢复」提示，等倒计时自己按结果收尾。
            if case .cooldown = state[type] ?? .idle {
                log("\(type.displayName) loaded during cooldown")
            } else {
                setState(type, .ready)
            }
        } else {
            if case .cooldown = state[type] ?? .idle {} else {
                setState(type, .unavailable)
            }
        }

        let callbacks = loadCallbacks.removeValue(forKey: type) ?? []
        for callback in callbacks { callback(success) }
    }

    // MARK: - 展示收尾（skill 6.1：播完即作废 + 自动重拉）

    private func finishPresentation() {
        guard let type = currentType else { return }
        currentType = nil
        isPresenting = false

        // 广告是一次性资源：无论成功失败，立刻为同类型重新拉取，保证随时可播。
        loadAd(of: type)
        startCooldown(for: type)
    }

    /// 面板用：随机 5-10 秒倒计时，结束后按重拉结果恢复高亮 / 置灰。
    private func startCooldown(for type: AdType) {
        cooldownTask?.cancel()
        let seconds = Int.random(in: 5...10)
        setState(type, .cooldown(seconds))

        cooldownTask = Task { @MainActor [weak self] in
            var remaining = seconds
            while remaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                guard let self else { return }
                remaining -= 1
                if remaining > 0 {
                    self.setState(type, .cooldown(remaining))
                } else {
                    self.setState(type, self.isAdReady(of: type) ? .ready : .unavailable)
                }
            }
        }
    }

    // MARK: - 状态写入（AdMob 回调在主线程，这里再兜一层，保证 @Published 只在主线程变）

    private func setState(_ type: AdType, _ newState: AdState) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.state[type] = newState }
            return
        }
        state[type] = newState
    }

    private func log(_ message: String) {
        NSLog("[CluvioAds] %@", message as NSString)
    }

    // MARK: - 宿主 VC（skill 6.2）

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard var top = scene?.keyWindow?.rootViewController else { return nil }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

// MARK: - 全屏广告回调（两种类型共用，skill 7.3）

extension CluvioAds: GADFullScreenContentDelegate {

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        if didEarnReward { log("rewarded ad closed after earning the reward") }
        finishPresentation()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        log("present failed: \(error.localizedDescription)")
        finishPresentation()
    }
}
