//
//  FlipAds.swift
//  Flip Chess: Dark Xiangqi — 广告抽象层（激励视频）
//
//  对齐 ad_layout skill 第 5~7 节的三件套：加载 / 就绪查询 / 展示。
//  本文件是唯一的平台适配边界 —— 换广告平台时只改这里，调用方（结算页 Play again 等）不动。
//
//  AdMob 适配要点：
//    · 全屏广告是一次性资源：每次展示后（播完 / 中途关闭 / 展示失败）立刻重新 load
//    · 展示前预检「是否就绪」与「宿主 VC」，未就绪绝不 present，避免崩溃
//    · 激励视频的奖励回调（userDidEarnReward）先于关闭回调（adDidDismiss）触发
//    · present 宿主按 skill 6.2：优先前台活跃场景的 keyWindow，再逐级取最上层 presentedViewController
//    · AdMob 回调都在主线程，本类不做额外线程派发
//
//  展示策略为「尽力展示」（skill §8.5）：业务动作不等待广告 —— 未就绪时立即回调
//  earned=false 让玩法继续，同时后台预载供下次使用。产品侧的奖励入口若将来要求
//  「必须看完」，按回调里的 earned 判定即可，本文件不用改。
//
//  测试期使用 AdMob 官方测试 ID（须与 Info.plist 里的测试 App ID 搭配）；
//  正式 ID 到手后替换下面的常量与 Info.plist 中的 `GADApplicationIdentifier`。
//

import Foundation
import UIKit
import GoogleMobileAds

final class FlipAds: NSObject {

    static let shared = FlipAds()

    // MARK: - 广告位 ID（正式 ID 到手后仅需替换此处）

    /// AdMob 官方测试激励视频 ID（须配合测试 App ID `ca-app-pub-3940256099942544~1458002511` 使用）。
    static let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    // MARK: - 内部状态

    /// 广告对象（适配边界之内，不外泄）。
    private var rewardedAd: GADRewardedAd?

    private var isLoading = false
    private var isPresenting = false
    private var didEarnReward = false
    private var didStartSDK = false

    /// 加载结束后的回调（多次请求合并到一次加载里）。
    private var loadCallbacks: [(Bool) -> Void] = []

    /// 当前这次展示的结果回调：「是否看完并拿到奖励」。
    private var showCompletion: ((Bool) -> Void)?

    private override init() { super.init() }

    // MARK: - SDK 初始化

    /// 启动 Google Mobile Ads SDK 并预载一条激励视频。幂等，可重复调用。
    func start() {
        guard !didStartSDK else { return }
        didStartSDK = true
        GADMobileAds.sharedInstance().start { [weak self] _ in
            self?.log("SDK ready")
        }
        loadRewarded()
    }

    // MARK: - 三件套

    /// 是否已就绪（有广告对象在手，随时可播）。
    var isRewardedReady: Bool { rewardedAd != nil }

    /// 加载一条激励视频。已在加载中时不重复发起；加载结束统一回调本轮的等待者。
    func loadRewarded(completion: ((Bool) -> Void)? = nil) {
        if let completion { loadCallbacks.append(completion) }

        if rewardedAd != nil {
            flushLoadCallbacks(success: true)
            return
        }
        guard !isLoading else { return }

        isLoading = true
        log("loading rewarded ad")
        GADRewardedAd.load(withAdUnitID: Self.rewardedAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self else { return }
            self.isLoading = false

            if let error {
                self.log("rewarded load failed: \(error.localizedDescription)")
                self.flushLoadCallbacks(success: false)
                return
            }
            self.rewardedAd = ad
            self.log("rewarded ad ready")
            self.flushLoadCallbacks(success: true)
        }
    }

    /// 展示激励视频 —— 「尽力展示」：不等待、不阻塞调用方的流程。
    ///
    /// · 已就绪 → present（奖励回调先注册）；播完 / 中途关闭 / 展示失败后自动重拉，
    ///   并以 `earned`（是否看完并拿到奖励）回调一次。
    /// · 未就绪（还在加载 / 暂无填充 / 已有广告在播）→ 立即 `completion(false)`，
    ///   同时后台继续加载，供下次「即点即播」。
    func presentRewarded(completion: @escaping (Bool) -> Void) {
        guard !isPresenting else {
            log("another full-screen ad is presenting, skip")
            completion(false)
            return
        }
        guard let ad = rewardedAd, let host = Self.topViewController() else {
            log("rewarded ad not ready or no host VC, skip presentation")
            completion(false)
            loadRewarded()          // 后台预载，下次可用
            return
        }

        rewardedAd = nil            // 广告是一次性资源，展示即作废
        isPresenting = true
        didEarnReward = false
        showCompletion = completion

        ad.fullScreenContentDelegate = self
        // 先注册奖励回调，再 present（奖励回调先于关闭回调触发）。
        ad.present(fromRootViewController: host) { [weak self] in
            self?.didEarnReward = true
            self?.log("user did earn reward")
        }
    }

    // MARK: - 收尾

    private func flushLoadCallbacks(success: Bool) {
        let callbacks = loadCallbacks
        loadCallbacks.removeAll()
        for callback in callbacks { callback(success) }
    }

    /// 展示结束（skill 6.1：播完即作废 + 自动重拉）。
    private func finishPresentation() {
        guard isPresenting else { return }
        isPresenting = false

        let earned = didEarnReward
        didEarnReward = false

        let completion = showCompletion
        showCompletion = nil

        // 无论播完、中途关闭还是展示失败，立刻重拉，保证下次随时可播。
        loadRewarded()
        completion?(earned)
    }

    private func log(_ message: String) {
        NSLog("[FlipAds] %@", message as NSString)
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

// MARK: - 全屏广告回调（skill 7.3）

extension FlipAds: GADFullScreenContentDelegate {

    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        log(didEarnReward ? "rewarded ad closed after earning the reward" : "rewarded ad closed early")
        finishPresentation()
    }

    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        log("rewarded present failed: \(error.localizedDescription)")
        finishPresentation()
    }
}
