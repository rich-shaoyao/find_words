platform :ios, '17.2' # 与工程 IPHONEOS_DEPLOYMENT_TARGET 保持一致
use_frameworks!

# ── 两套依赖树，由环境变量切换 ───────────────────────────────────────────────
#
#   pod install                  → 含 6 家广告 SDK（广告版：渠道验证 / 带广告上架）
#   CLUVIO_NO_ADS=1 pod install  → 不含任何广告 SDK（无广告版：上架主力）
#
# 「无广告版」必须真的**不链接**这 6 个 framework —— 只靠编译宏
# （HIDDEN_AD_PANEL_ENABLED）只能关掉源码编译，关不掉 framework 链接，
# 所以必须在依赖层切换。这也是消除与第三方模板 binary 同源指纹的关键一步。
#
# 切换依赖树后需重跑 pod install（CocoaPods 会重算 Pods 工程与 Podfile.lock）。

ads_enabled = ENV['CLUVIO_NO_ADS'] != '1'

target 'find_words' do
  if ads_enabled
    # AdMob (Google Mobile Ads SDK) — 版本精确锁定 11.7.0
    pod 'Google-Mobile-Ads-SDK', '= 11.7.0'

    # Meta Audience Network
    pod 'FBAudienceNetwork'

    # Liftoff (Vungle SDK)
    pod 'VungleSDK-iOS'

    # Chartboost
    pod 'ChartboostSDK'

    # InMobi
    pod 'InMobiSDK'

    # Unity Ads
    pod 'UnityAds'
  end
end
